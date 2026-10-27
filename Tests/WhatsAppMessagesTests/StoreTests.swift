//
//  StoreTests.swift
//  WhatsAppMessagesTests
//
//  Created by David Sherlock on 2026.
//
//  Every query, against the synthetic container in Fixture.swift. Nothing
//  here reads anybody's messages.
//

import CryptoKit
import XCTest
@testable import WhatsAppMessages

class FixtureTestCase: XCTestCase {

    var root: URL!
    var store: WhatsAppStore!

    override func setUpWithError() throws {
        root = Fixture.make()
        store = try WhatsAppStore(container: root)
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: root)
    }

    func messages(_ query: MessageQuery) throws -> [Message] { try store.messages(query) }
    func ids(_ query: MessageQuery) throws -> [Int64] { try messages(query).map(\.id) }
}

final class ChatTests: FixtureTestCase {

    func testChatsAreNewestFirstAndHiddenOnesAreLeftOut() throws {
        XCTAssertEqual(try store.chats().map(\.id), [6, 3, 2, 1, 4])
    }

    func testHiddenChatsCanBeAskedFor() throws {
        let all = try store.chats(includeHidden: true)
        XCTAssertEqual(all.first?.id, 5)
        XCTAssertTrue(all[0].isHidden)
    }

    func testKindsComeFromTheAddress() throws {
        let kinds = Dictionary(uniqueKeysWithValues: try store.chats().map { ($0.id, $0.kind) })
        XCTAssertEqual(kinds, [1: .person, 2: .person, 3: .group, 4: .status, 6: .person])
    }

    func testTheChatNameIsTheAppsAndTheContactsIsTheAddressBooks() throws {
        let ada = try store.chat(id: 1)
        XCTAssertEqual(ada.name, "Ada L.", "what the chat list shows")
        XCTAssertEqual(ada.contact?.name, "Ada Lovelace")
        XCTAssertEqual(ada.contact?.nameSource, .addressBook)
        XCTAssertEqual(ada.contact?.phone, "+447700900123")
        XCTAssertEqual(ada.contact?.alternateJID, People.adaLID)
    }

    func testALidOnlyChatGetsItsNumberFromWhatsAppsOwnTable() throws {
        let charles = try store.chat(id: 2)
        XCTAssertEqual(charles.contact?.phone, "+447700900456")
        XCTAssertTrue(charles.isArchived)
    }

    func testALidWithNoMappingHasNoNumberAndFallsBackToAGroupsName() throws {
        let grace = try store.chat(id: 6)
        XCTAssertNil(grace.contact?.phone, "an @lid id's digits are not a number")
        XCTAssertEqual(grace.name, "Grace H.", "an empty chat name is no name")
        XCTAssertEqual(grace.contact?.nameSource, .groupMember)
    }

    func testCountsLeaveOutEventsAndCalls() throws {
        let ada = try store.chat(id: 1)
        XCTAssertEqual(ada.messageCount, 15, "17 rows less the system message and the call")
        XCTAssertEqual(ada.unreadCount, 2)
    }

    func testGroupsCountCurrentMembers() throws {
        XCTAssertEqual(try store.chat(id: 3).memberCount, 3)
        XCTAssertEqual(try store.chat(id: 3).name, "Analytical Engine")
    }

    func testMembersLeaveOutFormerOnesUnlessAsked() throws {
        let current = try store.members(of: 3)
        XCTAssertEqual(current.map(\.contact.jid), [People.adaLID, People.charlesLID, People.graceLID])
        XCTAssertTrue(current[0].isAdmin)
        XCTAssertEqual(current[0].contact.name, "Ada Lovelace", "an @lid member, named through its pair")
        XCTAssertEqual(try store.members(of: 3, includeFormer: true).count, 4)
    }

    func testAnUnknownChatIdThrows() {
        XCTAssertThrowsError(try store.chat(id: 999)) { XCTAssertEqual($0 as? WhatsAppError, .noSuchChat("999")) }
    }
}

final class MessageTests: FixtureTestCase {

    func testAConversationNewestFirstWithoutEvents() throws {
        let found = try ids(MessageQuery(chatID: 1, limit: 4))
        XCTAssertEqual(found, [117, 116, 115, 114])
        XCTAssertFalse(try ids(MessageQuery(chatID: 1, limit: 100)).contains(109))
        XCTAssertFalse(try ids(MessageQuery(chatID: 1, limit: 100)).contains(110))
    }

    func testEventsAndCallsWhenAskedFor() throws {
        let all = try messages(MessageQuery(chatID: 1, includeEvents: true, limit: 100))
        XCTAssertEqual(all.first { $0.id == 109 }?.kind, .system)
        XCTAssertEqual(all.first { $0.id == 109 }?.eventCode, 7)
        XCTAssertEqual(all.first { $0.id == 110 }?.kind, .call)
    }

    func testOldestFirst() throws {
        XCTAssertEqual(try ids(MessageQuery(chatID: 2, newestFirst: false)), [201, 202])
    }

    func testAnLidAddressedMessageIsFromTheSamePerson() throws {
        let reply = try store.message(id: 103)
        XCTAssertEqual(reply.sender?.jid, People.adaLID)
        XCTAssertEqual(reply.sender?.name, "Ada Lovelace")
        XCTAssertEqual(reply.sender?.phone, "+447700900123")
    }

    func testMineHaveNoSender() throws {
        XCTAssertNil(try store.message(id: 102).sender)
        XCTAssertTrue(try store.message(id: 102).isFromMe)
    }

    func testAGroupMessageIsFromItsMemberNotTheGroup() throws {
        XCTAssertEqual(try store.message(id: 301).sender?.name, "Ada Lovelace")
        XCTAssertEqual(try store.message(id: 302).sender?.phone, "+447700900456")
    }

    func testAReplyPointsAtTheRowItQuotes() throws {
        let quote = try XCTUnwrap(try store.message(id: 103).quote)
        XCTAssertEqual(quote.stanzaID, "STANZA101")
        XCTAssertEqual(quote.messageID, 101)
        XCTAssertEqual(quote.author?.name, "Ada Lovelace")
        XCTAssertNil(try store.message(id: 101).quote)
    }

    func testReactionsAsTheyStand() throws {
        let reactions = try store.message(id: 102).reactions
        // Ada changed 👍 to ❤️; Charles took his 🔥 back; mine stays.
        XCTAssertEqual(reactions.map(\.emoji), ["❤️", "😂"])
        XCTAssertEqual(reactions[0].from?.name, "Ada Lovelace")
        XCTAssertNil(reactions[1].from)
        XCTAssertEqual(reactions[0].date?.timeIntervalSinceReferenceDate ?? 0, fixtureEpoch + 112, accuracy: 0.01)
    }

    func testAPhotosCaptionIsItsText() throws {
        let photo = try store.message(id: 104)
        XCTAssertEqual(photo.kind, .image)
        XCTAssertEqual(photo.text, "The engine, assembled")
        XCTAssertEqual(photo.media?.mimeType, "image/jpeg")
        XCTAssertEqual(photo.media?.bytes, 2048)
        XCTAssertEqual(photo.media?.exists, true)
        XCTAssertEqual(photo.media?.path, root.appendingPathComponent("Message/Media/\(People.adaLID)/a/b/IMAGE-0001.jpg").path)
        XCTAssertNil(photo.media?.latitude, "coordinates belong to locations only")
    }

    func testVoiceNotesAndAudioFilesAreTold() throws {
        let voice = try store.message(id: 105)
        XCTAssertEqual(voice.kind, .voice)
        XCTAssertEqual(voice.media?.duration, 7)
        XCTAssertEqual(voice.media?.exists, false)
        XCTAssertEqual(try store.message(id: 106).kind, .audio)
    }

    func testADocumentKeepsItsFileName() throws {
        let document = try store.message(id: 107)
        XCTAssertEqual(document.media?.fileName, "Sketch of the Engine.pdf")
        XCTAssertNil(document.text)
    }

    func testDeletedMessagesHaveNoText() throws {
        let deleted = try store.message(id: 108)
        XCTAssertTrue(deleted.isDeleted)
        XCTAssertNil(deleted.text)
        XCTAssertNil(deleted.media)
    }

    func testLinksCarryTheirCard() throws {
        let link = try store.message(id: 111)
        XCTAssertEqual(link.kind, .link)
        XCTAssertEqual(link.link, LinkPreview(url: "https://example.com/page", title: "Example Page"))
        XCTAssertEqual(try store.message(id: 117).link, LinkPreview(url: "https://example.com/sure"),
                       "from WhatsApp's link record, not the text")
    }

    func testForwardedIsBitSeven() throws {
        XCTAssertTrue(try store.message(id: 112).isForwarded)
        XCTAssertFalse(try store.message(id: 101).isForwarded)
    }

    func testStarred() throws {
        XCTAssertTrue(try store.message(id: 101).isStarred)
        XCTAssertFalse(try store.message(id: 112).isStarred)
    }

    func testLocationsAndContactCards() throws {
        let place = try store.message(id: 113)
        XCTAssertEqual(place.media?.latitude, 51.5)
        XCTAssertEqual(place.media?.longitude, -0.12)
        let card = try store.message(id: 114)
        XCTAssertEqual(card.media?.contactName, "Mary Somerville")
        XCTAssertNil(card.media?.mimeType, "a vCard is not a MIME type")
    }

    func testAnUnknownTypeIsKeptByItsCode() throws {
        let unknown = try store.message(id: 115)
        XCTAssertEqual(unknown.kind, .other)
        XCTAssertEqual(unknown.typeCode, 66)
    }

    func testDatesAreCoreDataSeconds() throws {
        XCTAssertEqual(try store.message(id: 101).date.timeIntervalSince1970, fixtureEpoch + 100 + 978_307_200, accuracy: 0.001)
    }

    func testAMissingMessageThrows() {
        XCTAssertThrowsError(try store.message(id: 9999)) { XCTAssertEqual($0 as? WhatsAppError, .noSuchMessage(9999)) }
    }

    func testLatestID() throws {
        XCTAssertEqual(try store.latestID(), 601)
    }
}

final class SearchTests: FixtureTestCase {

    func testTextIgnoringCase() throws {
        XCTAssertEqual(try ids(MessageQuery(text: "PUNCH")), [103])
    }

    func testWildcardsAreLiteral() throws {
        XCTAssertEqual(try ids(MessageQuery(text: "%")), [117])
        XCTAssertEqual(try ids(MessageQuery(text: "_")), [117])
    }

    func testCaseFoldsBeyondASCII() throws {
        XCTAssertEqual(try ids(MessageQuery(text: "CAFÉ")), [116])
    }

    func testCaptionsAndFileNamesAreSearched() throws {
        XCTAssertEqual(try ids(MessageQuery(text: "assembled")), [104])
        XCTAssertEqual(try ids(MessageQuery(text: "sketch of")), [107])
        XCTAssertEqual(try ids(MessageQuery(text: "placeholder")), [], "a deleted message's title is not its text")
    }

    func testFromAPersonUnderEitherAddress() throws {
        let both = try ids(MessageQuery(fromJIDs: store.directory.addresses(of: People.adaPhone), limit: 100))
        XCTAssertTrue(both.contains(103), "@lid-addressed")
        XCTAssertTrue(both.contains(301), "a group message from her")
        XCTAssertFalse(both.contains(201))
    }

    func testFromMe() throws {
        XCTAssertEqual(try ids(MessageQuery(chatID: 1, fromMe: true)), [116, 105, 102])
    }

    func testSinceUntilAndAfter() throws {
        let window = MessageQuery(since: Date(timeIntervalSinceReferenceDate: fixtureEpoch + 300),
                                  until: Date(timeIntervalSinceReferenceDate: fixtureEpoch + 410))
        XCTAssertEqual(try ids(window), [301, 202, 201])
        XCTAssertEqual(try ids(MessageQuery(afterID: 302)), [303, 501, 601])
    }

    func testKindsVoiceIsNotAudio() throws {
        XCTAssertEqual(try ids(MessageQuery(kinds: [.voice])), [105])
        XCTAssertEqual(try ids(MessageQuery(kinds: [.voice, .audio])), [106, 105])
        XCTAssertEqual(try ids(MessageQuery(kinds: [.other])), [115])
    }

    func testTheLimitHolds() throws {
        XCTAssertEqual(try ids(MessageQuery(limit: 2)).count, 2)
        XCTAssertEqual(try ids(MessageQuery(text: "e", limit: 2)).count, 2)
        XCTAssertEqual(try ids(MessageQuery(text: "é", limit: 1)).count, 1)
    }

    func testTheLimitHoldsWhenFilteringAfterTheQuery() throws {
        // Two non-ASCII matches, so the limit is applied after decoding.
        let writer = FixtureDatabase(path: root.appendingPathComponent("ChatStorage.sqlite").path)
        writer.exec("insert into ZWAMESSAGE (Z_PK, ZCHATSESSION, ZMESSAGETYPE, ZISFROMME, ZTEXT, ZMESSAGEDATE) values (950, 2, 0, 1, 'Déjà vu', \(fixtureEpoch + 999))")
        store = try store.refreshed()
        XCTAssertEqual(try ids(MessageQuery(text: "É", limit: 5)), [950, 116])
        XCTAssertEqual(try ids(MessageQuery(text: "É", limit: 1)), [950])
    }
}

final class StatsTests: FixtureTestCase {

    func testCountsAndNoContent() throws {
        let stats = try store.stats()
        XCTAssertEqual(stats.schema, SchemaInfo(modelVersion: "2.12.14", isKnown: true))
        XCTAssertEqual(stats.chats[.person], 4)
        XCTAssertEqual(stats.chats[.group], 1)
        XCTAssertEqual(stats.messages[.text], 13)
        XCTAssertEqual(stats.messages[.voice], 1)
        XCTAssertEqual(stats.messages[.audio], 1)
        XCTAssertEqual(stats.sent, 5)
        XCTAssertEqual(stats.mediaRecords, 4)
        XCTAssertEqual(stats.mediaOnDisk, 2)
        XCTAssertEqual(stats.addressBook, 1)
        XCTAssertEqual(stats.lidMappings, 2)
    }
}

final class MediaAuditTests: FixtureTestCase {

    func testFilesNoRecordNames() throws {
        let audit = try store.mediaAudit()
        XCTAssertEqual(audit.filesOnDisk, 6, "the hidden file is not WhatsApp's")
        XCTAssertEqual(audit.unreferenced.map(\.relativePath), [
            "\(Fixture.adaFolder)/x/y/ORPHAN-0001.jpg",
            "\(Fixture.adaFolder)/x/y/ORPHAN-0002.jpg",
            "Media/\(People.group)/x/y/ORPHAN-0003.mp4",
        ])
        XCTAssertEqual(audit.referencedPaths, 5)
        XCTAssertEqual(audit.referencedPresent, 3)
        XCTAssertEqual(audit.referencedMissing, 2)
    }

    func testEachFileIsTiedToItsChatThroughEitherAddress() throws {
        let audit = try store.mediaAudit()
        XCTAssertEqual(audit.unreferenced.map(\.chatID), [1, 1, 3], "Ada's folder is named by her @lid id")
        XCTAssertEqual(audit.unreferenced[0].folderJID, People.adaLID)
    }

    func testClonesFreeNothingOnTheirOwn() throws {
        let audit = try store.mediaAudit()
        XCTAssertTrue(audit.unreferenced[1].isClone)
        XCTAssertEqual(audit.unreferenced[1].privateBytes, 0)
        XCTAssertEqual(audit.unreferenced[1].bytes, 65536)
        XCTAssertFalse(audit.unreferenced[2].isClone)
        XCTAssertGreaterThan(audit.unreferenced[2].privateBytes ?? 0, 0)
    }

    func testTheAuditDeletesNothing() throws {
        _ = try store.mediaAudit()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Message/\(Fixture.adaFolder)/x/y/ORPHAN-0001.jpg").path))
    }
}

final class SnapshotTests: XCTestCase {

    func hashes(_ root: URL) -> [String: String] {
        var out: [String: String] = [:]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        for name in names where name.contains(".sqlite") {
            let data = (try? Data(contentsOf: root.appendingPathComponent(name))) ?? Data()
            out[name] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return out
    }

    func testReadingWhileWhatsAppWritesChangesNoByteOfItsFiles() throws {
        let root = Fixture.make()
        defer { try? FileManager.default.removeItem(at: root) }
        // WhatsApp keeps its connection, and so its log and index, open.
        let writer = FixtureDatabase(path: root.appendingPathComponent("ChatStorage.sqlite").path)
        writer.exec("PRAGMA wal_autocheckpoint=0")
        writer.exec("insert into ZWAPROFILEPUSHNAME (Z_PK, ZJID, ZPUSHNAME) values (99, 'x@lid', 'x')")
        let before = hashes(root)
        XCTAssertNotNil(before["ChatStorage.sqlite-shm"])

        let store = try WhatsAppStore(container: root)
        _ = try store.messages(MessageQuery(limit: 500))
        _ = try store.chats()
        XCTAssertEqual(hashes(root), before)
        withExtendedLifetime(writer) {}
    }

    func testRowsStillInTheLogAreRead() throws {
        let root = Fixture.make()
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = FixtureDatabase(path: root.appendingPathComponent("ChatStorage.sqlite").path)
        writer.exec("PRAGMA wal_autocheckpoint=0")
        writer.exec("insert into ZWAMESSAGE (Z_PK, ZCHATSESSION, ZMESSAGETYPE, ZISFROMME, ZTEXT, ZMESSAGEDATE) values (900, 2, 0, 1, 'only in the log', \(fixtureEpoch + 999))")
        let store = try WhatsAppStore(container: root)
        XCTAssertEqual(try store.message(id: 900).text, "only in the log")
        withExtendedLifetime(writer) {}
    }

    func testRefreshedSeesWhatArrivedSince() throws {
        let root = Fixture.make()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WhatsAppStore(container: root)
        let writer = FixtureDatabase(path: root.appendingPathComponent("ChatStorage.sqlite").path)
        writer.exec("insert into ZWAMESSAGE (Z_PK, ZCHATSESSION, ZMESSAGETYPE, ZISFROMME, ZTEXT, ZMESSAGEDATE) values (901, 2, 0, 1, 'new', \(fixtureEpoch + 999))")
        XCTAssertEqual(try store.latestID(), 601, "a store is a snapshot")
        XCTAssertEqual(try store.refreshed().latestID(), 901)
    }

    func testTheCopyIsGoneAfterwards() throws {
        let root = Fixture.make()
        defer { try? FileManager.default.removeItem(at: root) }
        let temp = FileManager.default.temporaryDirectory
        let name = WhatsAppContainer.chatStorage(root).lastPathComponent
        // The reader's private copies of this store; other processes' readers may share the folder.
        func copies() -> Set<String> {
            Set(((try? FileManager.default.contentsOfDirectory(atPath: temp.path)) ?? []).filter {
                $0.hasPrefix("sqlite-reader-")
                    && FileManager.default.fileExists(atPath: temp.appendingPathComponent($0).appendingPathComponent(name).path)
            })
        }
        let before = copies()
        var whileOpen: Set<String> = []
        do {
            let store = try WhatsAppStore(container: root)
            _ = try store.chats()
            withExtendedLifetime(store) { whileOpen = copies().subtracting(before) }
        }
        XCTAssertEqual(whileOpen.count, 1)
        XCTAssertEqual(copies().subtracting(before), [])
    }
}

final class OpeningTests: XCTestCase {

    func testAMissingColumnIsRefusedByName() {
        let root = Fixture.make(dropColumn: "ZWAMESSAGE.ZSTANZAID")
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try WhatsAppStore(container: root)) {
            XCTAssertEqual($0 as? WhatsAppError, .unsupportedSchema(version: "2.12.14", missing: ["ZWAMESSAGE.ZSTANZAID"]))
        }
    }

    func testAnUncheckedVersionIsReadAndSaysSo() throws {
        let root = Fixture.make(version: "2.99.0")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WhatsAppStore(container: root)
        XCTAssertEqual(store.schema, SchemaInfo(modelVersion: "2.99.0", isKnown: false))
        XCTAssertFalse(try store.chats().isEmpty)
    }

    func testAnEmptyContainerHasNoDatabase() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wa-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try WhatsAppStore(container: root)) {
            XCTAssertEqual($0 as? WhatsAppError, .noDatabase(root.appendingPathComponent("ChatStorage.sqlite").path))
        }
    }

    func testAnUnreadableDatabaseIsAPermissionProblem() throws {
        let root = Fixture.make()
        let file = root.appendingPathComponent("ChatStorage.sqlite").path
        defer {
            chmod(file, 0o644)
            try? FileManager.default.removeItem(at: root)
        }
        chmod(file, 0o000)
        XCTAssertThrowsError(try WhatsAppStore(container: root)) { XCTAssertEqual($0 as? WhatsAppError, .notPermitted(file)) }
    }

    func testMissingAppMissingDatabaseAndRefusalAreTold() {
        XCTAssertEqual(WhatsAppStore.missing(containerExists: false, databaseExists: false, refused: false,
                                             appInstalled: { false }, path: "/p"), .noApp)
        XCTAssertEqual(WhatsAppStore.missing(containerExists: false, databaseExists: false, refused: false,
                                             appInstalled: { true }, path: "/p"), .noDatabase("/p"))
        XCTAssertEqual(WhatsAppStore.missing(containerExists: true, databaseExists: false, refused: false,
                                             appInstalled: { true }, path: "/p"), .noDatabase("/p"))
        XCTAssertEqual(WhatsAppStore.missing(containerExists: true, databaseExists: true, refused: true,
                                             appInstalled: { true }, path: "/p"), .notPermitted("/p"))
        XCTAssertNil(WhatsAppStore.missing(containerExists: true, databaseExists: true, refused: false,
                                           appInstalled: { true }, path: "/p"))
    }

    func testOptionalStoresAreOptional() throws {
        let root = Fixture.make()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: root.appendingPathComponent("ContactsV2.sqlite"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("LID.sqlite"))
        let store = try WhatsAppStore(container: root)
        XCTAssertEqual(try store.chat(id: 1).contact?.name, "Ada L.", "the chat's own name, with no address book")
        XCTAssertNil(try store.chat(id: 2).contact?.phone, "no @lid table, no number")
    }
}
