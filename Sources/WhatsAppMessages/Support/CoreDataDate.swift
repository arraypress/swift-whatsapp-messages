//
//  CoreDataDate.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// WhatsApp's dates: Core Data timestamps, SECONDS since 1 January 2001 —
/// Apple's reference date, 978,307,200 seconds after the Unix epoch — stored
/// as a real with a fraction.
enum CoreDataDate {

    /// A stored value as a date, or `nil` for NULL or 0.
    static func date(_ stored: Double?) -> Date? {
        guard let stored, stored != 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: stored)
    }

    /// A date as the value queries compare against.
    static func stored(_ date: Date) -> Double { date.timeIntervalSinceReferenceDate }

    /// A Unix time in milliseconds — what the reaction records carry.
    static func date(unixMilliseconds: UInt64) -> Date? {
        guard unixMilliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(unixMilliseconds) / 1000)
    }
}
