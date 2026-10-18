//
//  Member.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Somebody in a group.
public struct Member: Sendable, Equatable, Codable {

    /// Who.
    public let contact: Contact

    /// Whether they administer the group.
    public let isAdmin: Bool

    /// Whether they are still in it. Members who left keep their row.
    public let isActive: Bool

    /// A member from its parts.
    public init(contact: Contact, isAdmin: Bool = false, isActive: Bool = true) {
        self.contact = contact
        self.isAdmin = isAdmin
        self.isActive = isActive
    }
}
