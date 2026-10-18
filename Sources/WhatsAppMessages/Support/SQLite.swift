//
//  SQLite.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  The smallest SQLite wrapper that runs this library's queries — opened
//  only ever on a private COPY of WhatsApp's files (see DatabaseSnapshot).
//

import Foundation
import SQLite3

/// A connection to a snapshot, that runs SELECTs and nothing else.
///
/// Opened read-write on purpose — the copy carries WhatsApp's write-ahead
/// log, and folding a log into a read needs an index built beside it — and
/// then locked down with `PRAGMA query_only`, so a statement that writes is
/// refused by SQLite itself. Values are bound, never pasted into SQL.
final class SQLiteDatabase {

    private let handle: OpaquePointer

    /// Where the open file is.
    let path: String

    /// Opens a snapshot file.
    init(path: String) throws {
        self.path = path
        var pointer: OpaquePointer?
        let result = sqlite3_open_v2(path, &pointer, SQLITE_OPEN_READWRITE, nil)
        guard result == SQLITE_OK, let pointer else {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(result)"
            if let pointer { sqlite3_close_v2(pointer) }
            throw WhatsAppError.readFailed(message)
        }
        handle = pointer
        sqlite3_busy_timeout(handle, 2000)
        try execute("PRAGMA query_only = 1")
    }

    deinit { sqlite3_close_v2(handle) }

    /// Runs a pragma.
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw WhatsAppError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Runs a query, handing each row to `row`.
    ///
    /// - Parameters:
    ///   - sql: The statement. Values belong in `parameters`, never here.
    ///   - parameters: Bound in order, standing in for each `?`.
    func query(_ sql: String, _ parameters: [SQLiteValue] = [], row: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw WhatsAppError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }

        for (offset, parameter) in parameters.enumerated() {
            let index = Int32(offset + 1)
            switch parameter {
            case .integer(let value):
                sqlite3_bind_int64(statement, index, value)
            case .double(let value):
                sqlite3_bind_double(statement, index, value)
            case .text(let value):
                // SQLITE_TRANSIENT: SQLite copies the bytes rather than
                // holding a pointer into a Swift string about to go away.
                sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }

        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW { try row(Row(statement: statement)); continue }
            if step == SQLITE_DONE { return }
            throw WhatsAppError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// The columns of a table, upper-cased; empty when there is no such table.
    func columns(of table: String) throws -> Set<String> {
        var names: Set<String> = []
        try query("select name from pragma_table_info(?)", [.text(table)]) { row in
            if let name = row.text(0) { names.insert(name.uppercased()) }
        }
        return names
    }

    /// One row of a result.
    struct Row {

        let statement: OpaquePointer

        /// Whether a column is NULL.
        func isNull(_ index: Int32) -> Bool { sqlite3_column_type(statement, index) == SQLITE_NULL }

        /// An integer column; 0 for NULL.
        func integer(_ index: Int32) -> Int64 { sqlite3_column_int64(statement, index) }

        /// An integer column, or `nil` for NULL.
        func optionalInteger(_ index: Int32) -> Int64? { isNull(index) ? nil : integer(index) }

        /// A floating-point column, or `nil` for NULL.
        func double(_ index: Int32) -> Double? { isNull(index) ? nil : sqlite3_column_double(statement, index) }

        /// A text column, or `nil` for NULL.
        func text(_ index: Int32) -> String? {
            guard let bytes = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: bytes)
        }

        /// A text column with empty strings as `nil` — WhatsApp stores both.
        func nonEmptyText(_ index: Int32) -> String? {
            guard let text = text(index), !text.isEmpty else { return nil }
            return text
        }

        /// A blob column, or `nil` for NULL.
        func data(_ index: Int32) -> Data? {
            guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
        }
    }
}

/// A value bound into a query.
enum SQLiteValue {
    case integer(Int64)
    case double(Double)
    case text(String)
}
