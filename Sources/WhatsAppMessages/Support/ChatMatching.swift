//
//  ChatMatching.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import ContactsKit
import Foundation

/// Which conversation somebody meant.
public enum ChatMatching {

    /// The chats a query names, best match only.
    ///
    /// In order, the first rule that finds anything wins: the row id; an
    /// address (either of a person's two); a name exactly; a phone number,
    /// however written; a name containing the text. Ignoring case. Two chats
    /// is two answers, which the caller is told.
    public static func select(_ query: String, from chats: [Chat]) -> [Chat] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return [] }
        if let id = Int64(wanted), let byID = chats.first(where: { $0.id == id }) { return [byID] }

        func named(_ name: String?) -> Bool { name?.compare(wanted, options: .caseInsensitive) == .orderedSame }
        func contains(_ name: String?) -> Bool { name?.range(of: wanted, options: .caseInsensitive) != nil }
        let isPhone = ContactDirectory.looksLikePhone(wanted)

        let rules: [(Chat) -> Bool] = [
            { $0.jid == wanted || $0.contact?.alternateJID == wanted },
            { named($0.name) || named($0.contact?.name) },
            { chat in isPhone && chat.kind == .person && (chat.contact?.phone.map { PhoneMatch.same(wanted, $0) } ?? false) },
            { contains($0.name) || contains($0.contact?.name) },
        ]
        for rule in rules {
            let found = chats.filter(rule)
            if !found.isEmpty { return found }
        }
        return []
    }

    /// What to call a chat: its name, the person's name or number, or its
    /// address.
    public static func title(_ chat: Chat) -> String {
        chat.name ?? chat.contact?.name ?? chat.contact?.phone ?? chat.jid
    }

    /// What to call a contact.
    public static func title(_ contact: Contact) -> String {
        contact.name ?? contact.phone ?? contact.jid
    }
}
