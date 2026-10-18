//
//  JIDKind.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The kinds of address WhatsApp uses, by the part after `@`.
public enum JIDKind: String, Sendable, Equatable, Codable, CaseIterable {
    /// `447700900123@s.whatsapp.net` — the user part IS the phone number.
    case phone
    /// `123456789012345@lid` — WhatsApp's newer, number-free id. Its digits
    /// are NOT a phone number and must never be compared as one.
    case lid
    /// `…@g.us`
    case group
    /// `…@broadcast`
    case broadcast
    /// `status@…`, `…@status`, `…@lid.status`
    case status
    /// `…@newsletter` — a channel.
    case newsletter
    case other
}
