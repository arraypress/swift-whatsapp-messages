//
//  NameSource.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a name came from — they are not equally trustworthy.
public enum NameSource: String, Sendable, Equatable, Codable, CaseIterable {
    /// WhatsApp's copy of your address book (`ContactsV2.sqlite`): the name
    /// you gave them.
    case addressBook
    /// The name on the conversation (`ZPARTNERNAME`) — what the chat list
    /// shows.
    case chat
    /// The name a group remembers for a member.
    case groupMember
    /// The name they chose for themselves (`ZWAPROFILEPUSHNAME`). Anybody
    /// can choose anything; WhatsApp shows these with a `~`.
    case pushName
}
