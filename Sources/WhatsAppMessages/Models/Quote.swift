//
//  Quote.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The message a reply quotes.
public struct Quote: Sendable, Equatable, Codable {

    /// The quoted message's WhatsApp id (`ZSTANZAID`).
    public let stanzaID: String

    /// Its row, when it is in this database — a quote can outlive what it
    /// quotes.
    public var messageID: Int64?

    /// Who wrote it, when the reply recorded that.
    public var author: Contact?

    /// A quote from its parts.
    public init(stanzaID: String, messageID: Int64? = nil, author: Contact? = nil) {
        self.stanzaID = stanzaID
        self.messageID = messageID
        self.author = author
    }
}
