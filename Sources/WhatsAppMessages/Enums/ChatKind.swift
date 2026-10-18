//
//  ChatKind.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a conversation is.
///
/// From `ZSESSIONTYPE`, measured against the address each row carries: 0 is
/// one person (`@s.whatsapp.net` or `@lid`), 1 a group (`@g.us`), 2 a
/// broadcast list (`@broadcast`), 3 status updates (`@status`,
/// `@lid.status`). Anything else is kept as ``other`` rather than guessed.
public enum ChatKind: String, Sendable, Equatable, Codable, CodingKeyRepresentable, CaseIterable {
    case person
    case group
    case broadcast
    case status
    case newsletter
    case other
}
