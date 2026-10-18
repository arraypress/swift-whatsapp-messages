//
//  ContactDirectory.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  Who an address is. WhatsApp scatters it over three databases.
//

import ContactsKit
import Foundation

/// Names and numbers for WhatsApp addresses, from everything WhatsApp keeps.
///
/// Built once by ``WhatsAppStore`` from:
///
/// - `ContactsV2.sqlite` — WhatsApp's copy of the address book: name, phone
///   address, and `@lid` id, so it pairs the two forms itself;
/// - `LID.sqlite` — `ZWAZACCOUNT`, every `@lid` id WhatsApp has met with its
///   number, address book or not;
/// - the chat store — the name on each conversation, the names groups keep
///   for members, and the names people chose for themselves.
///
/// Measured on one Mac: every `@lid` address in the store resolved to a
/// number through these tables, and every person to a name.
public struct ContactDirectory: Sendable {

    private let addressBook: [String: String]
    private let alternates: [String: String]
    private let chatNames: [String: String]
    private let memberNames: [String: String]
    private let pushNames: [String: String]

    /// A directory from its sources. Every map is keyed by address.
    ///
    /// - Parameters:
    ///   - addressBook: names from the address book.
    ///   - pairs: `@lid` ids with the phone address of the same person.
    ///   - chatNames: names on one-to-one conversations.
    ///   - memberNames: names groups keep for members.
    ///   - pushNames: names people chose for themselves.
    public init(
        addressBook: [String: String] = [:],
        pairs: [(lid: String, phone: String)] = [],
        chatNames: [String: String] = [:],
        memberNames: [String: String] = [:],
        pushNames: [String: String] = [:]
    ) {
        self.addressBook = addressBook
        var alternates: [String: String] = [:]
        for pair in pairs where !pair.lid.isEmpty && !pair.phone.isEmpty {
            alternates[pair.lid] = pair.phone
            alternates[pair.phone] = pair.lid
        }
        self.alternates = alternates
        self.chatNames = chatNames
        self.memberNames = memberNames
        self.pushNames = pushNames
    }

    /// The same person's other address — phone for an `@lid` id, or the
    /// reverse — when WhatsApp paired them.
    public func alternate(_ jid: String) -> String? { alternates[jid] }

    /// Every address a person is known by: this one, and its pair.
    public func addresses(of jid: String) -> [String] {
        [jid] + (alternates[jid].map { [$0] } ?? [])
    }

    /// Everything known about an address.
    ///
    /// The name is the first found of: the address book, the conversation's
    /// name, a group's name for them, their own chosen name — each tried on
    /// both of their addresses. The number comes from a phone address, never
    /// from an `@lid` id's digits.
    public func contact(for jid: String) -> Contact {
        let other = alternates[jid]
        let addresses = [jid] + (other.map { [$0] } ?? [])
        let sources: [(NameSource, [String: String])] = [
            (.addressBook, addressBook), (.chat, chatNames), (.groupMember, memberNames), (.pushName, pushNames),
        ]
        var name: String?
        var source: NameSource?
        search: for (kind, map) in sources {
            for address in addresses {
                if let found = map[address], !found.trimmingCharacters(in: .whitespaces).isEmpty {
                    name = found
                    source = kind
                    break search
                }
            }
        }
        return Contact(jid: jid, alternateJID: other,
                       phone: JIDs.phone(jid) ?? other.flatMap(JIDs.phone),
                       name: name, nameSource: source)
    }

    /// Every person-address the directory knows of.
    public var knownJIDs: [String] {
        let all = Set(addressBook.keys).union(alternates.keys).union(chatNames.keys)
            .union(memberNames.keys).union(pushNames.keys)
        return all.filter { [.phone, .lid].contains(JIDs.kind($0)) }.sorted()
    }

    /// The people a phone number, address or name means.
    ///
    /// An address matches itself and its pair; a number matches phone
    /// addresses by ContactsKit's `PhoneMatch` (the last nine digits) and is
    /// never compared with an `@lid` id; a name matches exactly first, then
    /// by containing the text. One answer per person: a phone address and
    /// its `@lid` pair are the same contact.
    public func resolve(_ query: String) -> [Contact] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return [] }

        var jids: [String] = []
        if JIDs.looksLikeJID(wanted) {
            jids = [wanted]
        } else if Self.looksLikePhone(wanted) {
            jids = knownJIDs.filter { JIDs.kind($0) == .phone && PhoneMatch.same(wanted, JIDs.user($0)) }
            if jids.isEmpty, let typed = JIDs.jid(forPhone: wanted) { jids = [typed] }
        } else {
            let contacts = knownJIDs.map(contact(for:))
            let exact = contacts.filter { $0.name?.compare(wanted, options: .caseInsensitive) == .orderedSame }
            let found = exact.isEmpty ? contacts.filter { $0.name?.range(of: wanted, options: .caseInsensitive) != nil } : exact
            jids = found.map(\.jid)
        }

        // One per person: prefer the phone address, and drop its pair.
        var seen: Set<String> = []
        var out: [Contact] = []
        for jid in jids.sorted(by: { JIDs.kind($0) == .phone && JIDs.kind($1) != .phone }) {
            guard !seen.contains(jid) else { continue }
            seen.formUnion(addresses(of: jid))
            out.append(contact(for: jid))
        }
        return out
    }

    /// Whether text is a phone number as somebody would type it: digits,
    /// spaces and `+()-.` only, at least seven digits.
    public static func looksLikePhone(_ text: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789+()-. ")
        return text.unicodeScalars.allSatisfy(allowed.contains)
            && text.filter(\.isASCIIDigitCharacter).count >= PhoneMatch.minimumDigits
    }
}
