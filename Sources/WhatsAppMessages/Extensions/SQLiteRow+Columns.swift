//
//  SQLiteRow+Columns.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  How this library reads a row's columns: integers as 0 when NULL (as
//  SQLite's own column reader gives them), and empty text and blobs as
//  absent — WhatsApp stores both.
//

import Foundation
import SQLiteReader

extension SQLiteRow {

    /// Whether a column is NULL.
    func isNull(_ index: Int) -> Bool { self[index].isNull }

    /// An integer column; 0 for NULL, a real truncated toward zero.
    func integer(_ index: Int) -> Int64 {
        if let value = self[index].int { return Int64(value) }
        if let value = self[index].double, let whole = Int64(exactly: value.rounded(.towardZero)) { return whole }
        return 0
    }

    /// An integer column, or `nil` for NULL.
    func optionalInteger(_ index: Int) -> Int64? { isNull(index) ? nil : integer(index) }

    /// A floating-point column, or `nil` for NULL.
    func double(_ index: Int) -> Double? { self[index].double }

    /// A text column, or `nil` for NULL.
    func text(_ index: Int) -> String? { self[index].string }

    /// A text column with empty strings as `nil` — WhatsApp stores both.
    func nonEmptyText(_ index: Int) -> String? {
        guard let text = text(index), !text.isEmpty else { return nil }
        return text
    }

    /// A blob column, or `nil` for NULL or an empty blob.
    func data(_ index: Int) -> Data? {
        guard let data = self[index].data, !data.isEmpty else { return nil }
        return data
    }
}
