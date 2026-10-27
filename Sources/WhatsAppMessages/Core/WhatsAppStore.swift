//
//  WhatsAppStore.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  WhatsApp for Mac's own store, read from a private copy and never written.
//

import Foundation
import SQLiteReader

/// Everything WhatsApp for Mac has stored, read-only.
///
/// ```swift
/// let store = try WhatsAppStore()
/// for chat in try store.chats().prefix(10) {
///     print(chat.id, ChatMatching.title(chat), chat.lastMessageAt ?? .distantPast)
/// }
/// let recent = try store.messages(MessageQuery(chatID: 12, limit: 20))
/// ```
///
/// Reads `ChatStorage.sqlite` — a Core Data store, unencrypted — from the
/// native app's group container. **WhatsApp's files are never opened:** the
/// database and its write-ahead log are copied into a private folder and
/// read there (see `SteadySnapshot` for the measurement that made this the
/// rule). A store is a snapshot of the moment it was made; ``refreshed()``
/// takes a new one.
///
/// The schema is WhatsApp's, undocumented, and changes with the app. The
/// store checks the columns it reads when it opens and refuses by name if
/// any are gone; ``schema`` says whether this model version was checked.
public final class WhatsAppStore {

    private let database: SQLiteReader

    /// The group container read from.
    public let container: URL

    /// What the store says about its shape.
    public let schema: SchemaInfo

    /// Names and numbers for addresses.
    public let directory: ContactDirectory

    /// Opens WhatsApp's store, or says why it cannot.
    ///
    /// - Parameter container: The group container; the app's own by default.
    ///   Tests pass a folder holding a synthetic store.
    public init(container: URL? = nil) throws {
        let container = container ?? WhatsAppContainer.defaultURL
        let chatStorage = WhatsAppContainer.chatStorage(container)
        if let missing = Self.missing(
            containerExists: FileManager.default.fileExists(atPath: container.path),
            databaseExists: FileManager.default.fileExists(atPath: chatStorage.path),
            refused: FileChecks.access(chatStorage.path) == .refused,
            appInstalled: { WhatsAppContainer.isAppInstalled },
            path: chatStorage.path
        ) { throw missing }

        self.container = container
        database = try SteadySnapshot.open(chatStorage)

        var plist: Data?
        try database.read(StoreQueries.metadata) { plist = $0.data(0) }
        let version = SchemaCheck.modelVersion(plist)
        var present: [String: Set<String>] = [:]
        for table in SchemaCheck.required.keys { present[table] = database.columns(of: table) }
        let missing = SchemaCheck.missing(present)
        guard missing.isEmpty else { throw WhatsAppError.unsupportedSchema(version: version, missing: missing) }
        schema = SchemaInfo(modelVersion: version, isKnown: version.map(SchemaCheck.knownVersions.contains) ?? false)

        directory = try Self.directory(chatStore: database, container: container)
    }

    /// The error for a store that is not there, or `nil` when it is.
    ///
    /// Whether the app is installed is asked only when the container is
    /// missing — it decides between "install WhatsApp" and "sign in".
    static func missing(containerExists: Bool, databaseExists: Bool, refused: Bool,
                        appInstalled: () -> Bool, path: String) -> WhatsAppError? {
        if refused { return .notPermitted(path) }
        if !containerExists { return appInstalled() ? .noDatabase(path) : .noApp }
        if !databaseExists { return .noDatabase(path) }
        return nil
    }

    /// A store read again from WhatsApp's files as they are now.
    public func refreshed() throws -> WhatsAppStore { try WhatsAppStore(container: container) }

    // MARK: - Conversations

    /// Every conversation, most recent first.
    ///
    /// - Parameter includeHidden: Include conversations the app hides or
    ///   removed. Status updates and broadcast lists are always included —
    ///   filter on ``Chat/kind``.
    public func chats(includeHidden: Bool = false) throws -> [Chat] {
        var counts: [Int64: Int] = [:]
        try database.read(StoreQueries.messageCounts) { counts[$0.integer(0)] = Int($0.integer(1)) }
        var members: [Int64: Int] = [:]
        try database.read(StoreQueries.memberCounts) { members[$0.integer(0)] = Int($0.integer(1)) }

        var chats: [Chat] = []
        try database.read(StoreQueries.chats) { row in
            let id = row.integer(0)
            let jid = row.text(1) ?? ""
            let kind = Self.chatKind(sessionType: row.integer(2), jid: jid)
            let hidden = row.integer(7) != 0 || row.integer(8) != 0
            guard includeHidden || !hidden else { return }
            let contact = kind == .person ? directory.contact(for: jid) : nil
            chats.append(Chat(
                id: id,
                jid: jid,
                kind: kind,
                name: row.nonEmptyText(3) ?? contact?.name,
                contact: contact,
                lastMessageAt: CoreDataDate.date(row.double(4)),
                messageCount: counts[id] ?? 0,
                unreadCount: max(Int(row.integer(5)), 0),
                isArchived: row.integer(6) != 0,
                isHidden: hidden,
                memberCount: members[id] ?? 0
            ))
        }
        return chats
    }

    /// One conversation by row.
    public func chat(id: Int64) throws -> Chat {
        guard let chat = try chats(includeHidden: true).first(where: { $0.id == id }) else {
            throw WhatsAppError.noSuchChat(String(id))
        }
        return chat
    }

    /// What a conversation is, from its session type and its address.
    ///
    /// The address decides where it is unambiguous; the session type only
    /// for one-to-one chats, whose addresses come in two forms.
    static func chatKind(sessionType: Int64, jid: String) -> ChatKind {
        switch JIDs.kind(jid) {
        case .group: return .group
        case .broadcast: return .broadcast
        case .status: return .status
        case .newsletter: return .newsletter
        case .phone, .lid: return sessionType == 0 ? .person : .other
        case .other:
            switch sessionType {
            case 0: return .person
            case 1: return .group
            case 2: return .broadcast
            case 3: return .status
            default: return .other
            }
        }
    }

    /// A group's members, current ones first.
    ///
    /// - Parameter includeFormer: Include people who left. Measured: when a
    ///   group moved to `@lid` addressing, its old phone-address member rows
    ///   stayed behind, inactive — so by default they are left out.
    public func members(of chatID: Int64, includeFormer: Bool = false) throws -> [Member] {
        var found: [Member] = []
        try database.read(StoreQueries.members, [.integer(chatID)]) { row in
            guard let jid = row.text(0) else { return }
            let active = row.integer(2) != 0
            guard includeFormer || active else { return }
            found.append(Member(contact: directory.contact(for: jid), isAdmin: row.integer(1) != 0, isActive: active))
        }
        return found
    }

    // MARK: - Messages

    /// The messages a query matches, with media, quotes, reactions and links.
    public func messages(_ query: MessageQuery = MessageQuery()) throws -> [Message] {
        let (sql, values, filterAfter) = StoreQueries.messages(query)
        var found: [Message] = []
        let wanted = query.text.flatMap { $0.isEmpty ? nil : $0 }
        try database.read(sql, values) { row in
            guard !filterAfter || found.count < query.limit else { return }
            let message = assemble(row)
            if filterAfter {
                if let kinds = query.kinds, !kinds.isEmpty, !kinds.contains(message.kind) { return }
                if let wanted, !Self.mentions(message, wanted) { return }
            }
            found.append(message)
        }
        return try decorate(found)
    }

    /// Whether a message's text, caption or file name holds some text,
    /// ignoring case in every script.
    static func mentions(_ message: Message, _ text: String) -> Bool {
        [message.text, message.media?.fileName, message.link?.title].contains {
            $0?.localizedCaseInsensitiveContains(text) ?? false
        }
    }

    /// One message by row.
    public func message(id: Int64) throws -> Message {
        var found: Message?
        try database.read(StoreQueries.message, [.integer(id)]) { found = assemble($0) }
        guard let found else { throw WhatsAppError.noSuchMessage(id) }
        return try decorate([found])[0]
    }

    /// The newest message row, for watching from.
    public func latestID() throws -> Int64 {
        var latest: Int64 = 0
        try database.read(StoreQueries.latestID) { latest = $0.integer(0) }
        return latest
    }

    /// A message from a row of ``StoreQueries/messageColumns``.
    private func assemble(_ row: SQLiteRow) -> Message {
        let isFromMe = row.integer(3) == 1
        let type = Int(row.integer(4))
        let hasMedia = !row.isNull(24)
        let mime = type == 4 ? nil : row.nonEmptyText(14)
        let kind = MessageKinds.kind(type: type, mimeType: mime)
        let title = row.nonEmptyText(15)
        let chatJID = row.text(23) ?? ""

        // The sender: a group names its member; a one-to-one message names
        // the other side, in whichever form of address it was sent under.
        var sender: Contact?
        if !isFromMe {
            let from = row.nonEmptyText(7)
            let jid = row.nonEmptyText(8) ?? from.flatMap { JIDs.kind($0) == .group ? nil : $0 } ?? chatJID
            sender = directory.contact(for: jid)
        }

        var media: MediaItem?
        if hasMedia, kind != .text, kind != .deleted, kind != .system, kind != .call, kind != .link {
            let relative = row.nonEmptyText(12)
            let path = relative.map { MediaPaths.absolute($0, in: WhatsAppContainer.messageFolder(container)) }
            media = MediaItem(
                relativePath: relative,
                path: path,
                exists: path.map { FileManager.default.fileExists(atPath: $0) } ?? false,
                bytes: max(row.integer(13), 0),
                mimeType: mime,
                fileName: kind == .document ? title : nil,
                duration: row.optionalInteger(16).flatMap { $0 > 0 ? Int($0) : nil },
                thumbnailPath: row.nonEmptyText(17) ?? row.nonEmptyText(18),
                latitude: kind == .location ? row.double(19) : nil,
                longitude: kind == .location ? row.double(20) : nil,
                contactName: kind == .contact ? VCard.formattedName(row.text(14)) : nil
            )
        }

        var text = row.nonEmptyText(5)
        if text == nil, MessageKinds.captionIsTitle(kind) { text = title }
        if kind == .deleted { text = nil }

        let quote = BlobDecoding.quote(row.data(21)).map { stored in
            Quote(stanzaID: stored.stanzaID, author: stored.author.map(directory.contact(for:)))
        }
        let reactions = BlobDecoding.reactions(row.data(22)).map { stored in
            Reaction(emoji: stored.emoji, from: stored.sender.map(directory.contact(for:)),
                     date: CoreDataDate.date(unixMilliseconds: stored.unixMilliseconds))
        }

        return Message(
            id: row.integer(0),
            stanzaID: row.nonEmptyText(1),
            chatID: row.integer(2),
            sender: sender,
            isFromMe: isFromMe,
            kind: kind,
            typeCode: type,
            text: text,
            date: CoreDataDate.date(row.double(6)) ?? Date(timeIntervalSinceReferenceDate: 0),
            media: media,
            quote: quote,
            reactions: reactions,
            link: kind == .link ? title.map { LinkPreview(url: "", title: $0) } : nil,
            isForwarded: MessageKinds.isForwarded(flags: row.integer(9)),
            isStarred: row.integer(10) == 1,
            eventCode: kind == .system ? Int(row.integer(11)) : nil
        )
    }

    /// Messages with their links and the rows their quotes point at.
    ///
    /// Two queries for the whole batch, in chunks under SQLite's
    /// bound-parameter limit.
    private func decorate(_ messages: [Message]) throws -> [Message] {
        guard !messages.isEmpty else { return messages }
        var links: [Int64: (url: String, title: String?)] = [:]
        var rows: [String: Int64] = [:]
        let stanzas = Array(Set(messages.compactMap { $0.quote?.stanzaID }))

        for chunk in Self.chunks(messages.map(\.id)) {
            try database.read(StoreQueries.links(count: chunk.count), chunk.map { .integer($0) }) { row in
                let id = row.integer(0)
                guard links[id] == nil, let url = row.nonEmptyText(1) else { return }
                links[id] = (url, row.nonEmptyText(2))
            }
        }
        for chunk in Self.chunks(stanzas) {
            try database.read(StoreQueries.stanzas(count: chunk.count), chunk.map { .text($0) }) { row in
                if let stanza = row.text(0) { rows[stanza] = row.integer(1) }
            }
        }

        return messages.map { message in
            var decorated = message
            if let found = links[message.id] {
                decorated.link = LinkPreview(url: found.url, title: message.link?.title ?? found.title)
            } else if message.kind == .link {
                decorated.link = Self.firstLink(in: message.text).map { LinkPreview(url: $0, title: message.link?.title) }
            }
            if var quote = message.quote {
                quote.messageID = rows[quote.stanzaID]
                decorated.quote = quote
            }
            return decorated
        }
    }

    /// The first web address in some text.
    static func firstLink(in text: String?) -> String? {
        guard let text, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    /// Values in chunks of 500 — under SQLite's bound-parameter limit.
    static func chunks<T>(_ values: [T]) -> [[T]] {
        stride(from: 0, to: values.count, by: 500).map { Array(values[$0..<min($0 + 500, values.count)]) }
    }

    // MARK: - Directory

    /// Names and numbers from the chat store and, when present, WhatsApp's
    /// address book and `@lid` table — each read from its own private copy.
    static func directory(chatStore: SQLiteReader, container: URL) throws -> ContactDirectory {
        var chatNames: [String: String] = [:]
        try chatStore.read(StoreQueries.chatNames) { row in
            if let jid = row.text(0), let name = row.nonEmptyText(1) { chatNames[jid] = name }
        }
        var memberNames: [String: String] = [:]
        try chatStore.read(StoreQueries.memberNames) { row in
            if let jid = row.text(0), let name = row.nonEmptyText(1) { memberNames[jid] = name }
        }
        var pushNames: [String: String] = [:]
        try chatStore.read(StoreQueries.pushNames) { row in
            if let jid = row.text(0), let name = row.nonEmptyText(1) { pushNames[jid] = name }
        }

        var book: [String: String] = [:]
        var pairs: [(lid: String, phone: String)] = []
        // Optional stores: an older app, or one never synced, may not have
        // them, and names then come from the chat store alone.
        if let contacts = try? SteadySnapshot.open(WhatsAppContainer.contacts(container)) {
            try? contacts.read(StoreQueries.addressBook) { row in
                let name = row.nonEmptyText(2)
                    ?? [row.nonEmptyText(3), row.nonEmptyText(4)].compactMap { $0 }.joined(separator: " ").nilIfEmpty
                    ?? row.nonEmptyText(5)
                let phone = row.nonEmptyText(0)
                let lid = row.nonEmptyText(1)
                if let name {
                    if let phone { book[phone] = name }
                    if let lid { book[lid] = name }
                }
                if let phone, let lid { pairs.append((lid, phone)) }
            }
        }
        if let lids = try? SteadySnapshot.open(WhatsAppContainer.lid(container)) {
            try? lids.read(StoreQueries.lidAccounts) { row in
                guard let lid = row.nonEmptyText(0), JIDs.kind(lid) == .lid,
                      let number = row.nonEmptyText(1), let phone = JIDs.jid(forPhone: number) else { return }
                pairs.append((lid, phone))
            }
        }
        return ContactDirectory(addressBook: book, pairs: pairs, chatNames: chatNames,
                                memberNames: memberNames, pushNames: pushNames)
    }

    // MARK: - Stats

    /// Counts across the store. No content.
    public func stats() throws -> StoreStats {
        var chats: [ChatKind: Int] = [:]
        for chat in try self.chats(includeHidden: true) { chats[chat.kind, default: 0] += 1 }

        var messages: [MessageKind: Int] = [:]
        try database.read(StoreQueries.typeCounts) { row in
            let kind = MessageKinds.kind(type: Int(row.integer(0)), mimeType: row.nonEmptyText(1))
            messages[kind, default: 0] += Int(row.integer(2))
        }
        var sent = 0
        try database.read(StoreQueries.sentCount) { sent = Int($0.integer(0)) }

        var records = 0
        var onDisk = 0
        let folder = WhatsAppContainer.messageFolder(container)
        try database.read(StoreQueries.mediaPaths) { row in
            guard let relative = row.text(0) else { return }
            records += 1
            if FileManager.default.fileExists(atPath: MediaPaths.absolute(relative, in: folder)) { onDisk += 1 }
        }

        return StoreStats(
            schema: schema, chats: chats, messages: messages, sent: sent,
            mediaRecords: records, mediaOnDisk: onDisk,
            addressBook: Self.count("select count(*) from ZWAADDRESSBOOKCONTACT", in: WhatsAppContainer.contacts(container)),
            lidMappings: Self.count("select count(*) from ZWAZACCOUNT where ZPHONENUMBER is not null",
                                    in: WhatsAppContainer.lid(container))
        )
    }

    /// One count from an optional store; 0 when it is not there.
    private static func count(_ sql: String, in file: URL) -> Int {
        guard let copy = try? SteadySnapshot.open(file) else { return 0 }
        var count = 0
        try? copy.read(sql) { count = Int($0.integer(0)) }
        return count
    }

    // MARK: - Media audit

    /// Files under `Message/Media` that no media record names.
    ///
    /// Walks the folder and sets every file against the media, thumbnail and
    /// link-preview paths the store holds. Reports each unreferenced file's
    /// size, what deleting it alone would free, and whether it is an APFS
    /// clone — a folder of clones frees nothing until every copy goes.
    /// Nothing is deleted: this only looks.
    public func mediaAudit() throws -> MediaAudit {
        var referenced: Set<String> = []
        try database.read(StoreQueries.referencedPaths) { row in
            if let path = row.text(0) { referenced.insert(path) }
        }

        let folder = WhatsAppContainer.messageFolder(container)
        let onDisk = Self.files(under: folder.appendingPathComponent("Media", isDirectory: true), relativeTo: folder)
        let present = referenced.intersection(onDisk.map(\.relative))

        var byFolder: [String: Int64] = [:]
        let chats = try self.chats(includeHidden: true)
        for chat in chats {
            byFolder[chat.jid] = chat.id
            if let other = directory.alternate(chat.jid) { byFolder[other] = chat.id }
        }

        let unreferenced = onDisk.filter { !referenced.contains($0.relative) }.map { file -> UnreferencedFile in
            let clone = FileClones.info(file.path)
            let jid = MediaPaths.folderJID(file.relative)
            return UnreferencedFile(
                relativePath: file.relative, path: file.path, bytes: file.bytes,
                privateBytes: clone?.privateBytes, isClone: clone?.sharesAllBlocks ?? false,
                folderJID: jid, chatID: jid.flatMap { byFolder[$0] }
            )
        }
        return MediaAudit(
            filesOnDisk: onDisk.count, referencedPaths: referenced.count,
            referencedPresent: present.count, referencedMissing: referenced.count - present.count,
            unreferenced: unreferenced
        )
    }

    /// Every regular file under a folder, hidden files aside, with its path
    /// relative to `base`.
    static func files(under root: URL, relativeTo base: URL) -> [(relative: String, path: String, bytes: Int64)] {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        let prefix = base.standardizedFileURL.path + "/"
        var found: [(String, String, Int64)] = []
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(prefix) else { continue }
            found.append((String(path.dropFirst(prefix.count)), path, Int64(values.fileSize ?? 0)))
        }
        return found.sorted { $0.0 < $1.0 }
    }
}

extension String {

    /// `nil` for an empty string.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
