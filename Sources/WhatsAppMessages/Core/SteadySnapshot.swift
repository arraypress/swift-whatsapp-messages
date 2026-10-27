//
//  SteadySnapshot.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  WHY A COPY, AND NOT A READ-ONLY OPEN. Measured on a scratch WAL database
//  with a writer open, as WhatsApp keeps one: a reader opened with
//  `mode=ro` / SQLITE_OPEN_READONLY still CHANGED the `-shm` file — readers
//  record their read marks there. So a read-only open of WhatsApp's store is
//  not a read; it writes into WhatsApp's container. Instead the database and
//  its write-ahead log are copied into a private folder by swift-sqlite-reader
//  (`.snapshot`) and read there. WhatsApp's files are only ever read as bytes.
//
//  What stays here is the one thing the reader does not do: checking that
//  WhatsApp did not write while the copy was taken, and taking it again if
//  it did.
//

import Foundation
import SQLiteReader

/// A private copy of one of WhatsApp's stores, taken while it held still.
enum SteadySnapshot {

    /// How many times to copy before giving up on a store that keeps moving.
    static let attempts = 4

    /// Copies the database at `source` and opens the copy.
    ///
    /// The copy is checked: if the database or its log changed size or
    /// modification time while being copied, it is copied again. WhatsApp
    /// writes in bursts, so a second attempt almost always lands between them.
    /// The copy is then locked down with `PRAGMA query_only`, so a statement
    /// that writes is refused by SQLite itself; it is deleted when the reader goes.
    static func open(_ source: URL) throws(WhatsAppError) -> SQLiteReader {
        for _ in 0..<attempts {
            let before = signature(source)
            let reader: SQLiteReader
            do { reader = try SQLiteReader(path: source, opening: .snapshot) } catch { throw WhatsAppError(error) }
            if signature(source) == before {
                do {
                    _ = try reader.rows("PRAGMA busy_timeout = 2000")
                    _ = try reader.rows("PRAGMA query_only = 1")
                } catch { throw WhatsAppError(error) }
                return reader
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw .busy("still changing after \(attempts) copies — try again")
    }

    /// Size and modification time of a database and its log — what changes
    /// when WhatsApp writes.
    static func signature(_ source: URL) -> [Double] {
        ["", "-wal"].flatMap { suffix -> [Double] in
            var info = stat()
            guard stat(source.path + suffix, &info) == 0 else { return [-1, -1] }
            return [Double(info.st_size),
                    Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9]
        }
    }
}
