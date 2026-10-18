//
//  Contact.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Somebody on WhatsApp, as far as this Mac's data can say who.
public struct Contact: Sendable, Equatable, Hashable, Codable {

    /// The address the row named: `447700900123@s.whatsapp.net` or an
    /// `@lid` id.
    public let jid: String

    /// The same person's other address, when WhatsApp's own tables pair a
    /// phone address with an `@lid` id.
    public var alternateJID: String?

    /// Their number, `+447700900123`, when it is known. Read from a phone
    /// address, or from WhatsApp's own `@lid` → number table — never from
    /// an `@lid` id's digits.
    public var phone: String?

    /// Their name, when anything on this Mac holds one.
    public var name: String?

    /// Where ``name`` came from.
    public var nameSource: NameSource?

    /// A contact from its parts.
    public init(jid: String, alternateJID: String? = nil, phone: String? = nil,
                name: String? = nil, nameSource: NameSource? = nil) {
        self.jid = jid
        self.alternateJID = alternateJID
        self.phone = phone
        self.name = name
        self.nameSource = nameSource
    }
}
