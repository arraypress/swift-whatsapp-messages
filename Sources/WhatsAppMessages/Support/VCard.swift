//
//  VCard.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The one thing read from a shared contact card: the name on it.
enum VCard {

    /// The `FN` line's value, unfolded, or `nil`.
    static func formattedName(_ card: String?) -> String? {
        guard let card, card.uppercased().contains("BEGIN:VCARD") else { return nil }
        // Folded lines continue with a leading space or tab (RFC 6350 §3.2).
        let unfolded = card.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "").replacingOccurrences(of: "\n\t", with: "")
        for line in unfolded.split(separator: "\n") {
            let upper = line.uppercased()
            guard upper.hasPrefix("FN:") || upper.hasPrefix("FN;"), let colon = line.firstIndex(of: ":") else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value.replacingOccurrences(of: "\\,", with: ",")
        }
        return nil
    }
}
