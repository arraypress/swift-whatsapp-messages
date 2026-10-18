//
//  Reaction.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An emoji somebody put on a message.
public struct Reaction: Sendable, Equatable, Codable {

    /// The emoji.
    public let emoji: String

    /// Who. `nil` for your own.
    public var from: Contact?

    /// When.
    public let date: Date?

    /// A reaction from its parts.
    public init(emoji: String, from: Contact? = nil, date: Date? = nil) {
        self.emoji = emoji
        self.from = from
        self.date = date
    }
}
