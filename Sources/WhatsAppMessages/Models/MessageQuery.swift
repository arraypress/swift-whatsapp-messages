//
//  MessageQuery.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which messages to read.
public struct MessageQuery: Sendable, Equatable {

    /// Only this conversation.
    public var chatID: Int64?

    /// Text to find, ignoring case — in the text, a caption or a document's
    /// name.
    public var text: String?

    /// Only messages from this person: any address of theirs. See
    /// ``ContactDirectory/addresses(of:)``.
    public var fromJIDs: [String]?

    /// Only messages you sent (`true`), or only others' (`false`).
    public var fromMe: Bool?

    /// Only these kinds.
    public var kinds: [MessageKind]?

    /// On or after.
    public var since: Date?

    /// Before.
    public var until: Date?

    /// Only rows after this one — what `watch` asks for.
    public var afterID: Int64?

    /// Include system messages and calls. Off by default: they are not things
    /// anybody wrote.
    public var includeEvents: Bool

    /// How many to return.
    public var limit: Int

    /// Newest first, the default; oldest first reads like a conversation.
    public var newestFirst: Bool

    /// A query; every filter optional.
    public init(
        chatID: Int64? = nil,
        text: String? = nil,
        fromJIDs: [String]? = nil,
        fromMe: Bool? = nil,
        kinds: [MessageKind]? = nil,
        since: Date? = nil,
        until: Date? = nil,
        afterID: Int64? = nil,
        includeEvents: Bool = false,
        limit: Int = 50,
        newestFirst: Bool = true
    ) {
        self.chatID = chatID
        self.text = text
        self.fromJIDs = fromJIDs
        self.fromMe = fromMe
        self.kinds = kinds
        self.since = since
        self.until = until
        self.afterID = afterID
        self.includeEvents = includeEvents
        self.limit = limit
        self.newestFirst = newestFirst
    }
}
