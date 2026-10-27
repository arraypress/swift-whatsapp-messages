//
//  WhatsAppError+SQLiteReader.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  The stores are read through swift-sqlite-reader; its errors are reported
//  as this library's own, so callers and messages stay the same.
//

import Foundation
import SQLiteReader

extension WhatsAppError {

    /// This library's error for a reader's.
    init(_ error: SQLiteReaderError) {
        switch error {
        case .notFound(let path): self = .noDatabase(path)
        case .permissionDenied(let path): self = .notPermitted(path)
        case .unreadable(_, let reason): self = .readFailed(reason)
        }
    }
}

extension SQLiteReader {

    /// Runs a query, handing each row over, and reports a failure as a
    /// ``WhatsAppError``.
    ///
    /// - Parameters:
    ///   - sql: The statement. Values belong in `values`, never here.
    ///   - values: Bound in order, standing in for each `?`.
    ///   - row: Called with each row.
    func read(_ sql: String, _ values: [SQLiteValue] = [], row: (SQLiteRow) -> Void) throws(WhatsAppError) {
        do { try query(sql, values, row: row) } catch { throw WhatsAppError(error) }
    }
}
