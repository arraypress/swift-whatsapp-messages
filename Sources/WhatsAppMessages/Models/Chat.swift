//
//  Chat.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A conversation, as the chat list shows it.
public struct Chat: Sendable, Equatable, Codable, Identifiable {

    /// The row (`Z_PK`) — what every verb takes back.
    public let id: Int64

    /// The conversation's address: a person's, or the group's `@g.us`.
    public let jid: String

    /// What it is.
    public let kind: ChatKind

    /// Its name: the group's subject, or the person's name as WhatsApp
    /// shows it. `nil` when nothing on this Mac names it.
    public var name: String?

    /// The other person, for a one-to-one chat — with their number when it is
    /// known.
    public var contact: Contact?

    /// When the last message was sent or received.
    public let lastMessageAt: Date?

    /// Messages in it, events and calls left out.
    public let messageCount: Int

    /// Unread, as the app counts them.
    public let unreadCount: Int

    /// Archived in the app.
    public let isArchived: Bool

    /// Hidden or removed in the app — kept in the database, not shown.
    public let isHidden: Bool

    /// Members, for a group.
    public let memberCount: Int

    /// A chat from its parts.
    public init(
        id: Int64,
        jid: String,
        kind: ChatKind = .person,
        name: String? = nil,
        contact: Contact? = nil,
        lastMessageAt: Date? = nil,
        messageCount: Int = 0,
        unreadCount: Int = 0,
        isArchived: Bool = false,
        isHidden: Bool = false,
        memberCount: Int = 0
    ) {
        self.id = id
        self.jid = jid
        self.kind = kind
        self.name = name
        self.contact = contact
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.unreadCount = unreadCount
        self.isArchived = isArchived
        self.isHidden = isHidden
        self.memberCount = memberCount
    }
}
