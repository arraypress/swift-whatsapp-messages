//
//  DatabaseSnapshot.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  WHY A COPY, AND NOT A READ-ONLY OPEN. Measured on a scratch WAL database
//  with a writer open, as WhatsApp keeps one: a reader opened with
//  `mode=ro` / SQLITE_OPEN_READONLY still CHANGED the `-shm` file — readers
//  record their read marks there. So a read-only open of WhatsApp's store is
//  not a read; it writes into WhatsApp's container. Instead the database and
//  its write-ahead log are cloned into a private folder (APFS clones: no
//  data is copied, it takes milliseconds) and read there. WhatsApp's files
//  are only ever read as bytes.
//

import Foundation

/// A private copy of a SQLite database and its log, deleted when done.
final class DatabaseSnapshot {

    /// The open copy.
    let database: SQLiteDatabase

    private let folder: URL

    /// How many times to copy before giving up on a store that keeps moving.
    static let attempts = 4

    /// Copies the database at `source` and opens the copy.
    ///
    /// The copy is checked: if the database or its log changed size or
    /// modification time while being copied, it is copied again. WhatsApp
    /// writes in bursts, so a second attempt almost always lands between them.
    init(of source: URL) throws {
        switch PermissionCheck.access(source.path) {
        case .readable: break
        case .missing: throw WhatsAppError.noDatabase(source.path)
        case .refused: throw WhatsAppError.notPermitted(source.path)
        }

        let fileManager = FileManager.default
        folder = fileManager.temporaryDirectory
            .appendingPathComponent("whatsapp-messages-\(UUID().uuidString)", isDirectory: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            var steady = false
            for _ in 0..<Self.attempts {
                let before = Self.signature(source)
                for suffix in ["", "-wal"] {
                    let from = URL(fileURLWithPath: source.path + suffix)
                    let to = URL(fileURLWithPath: target.path + suffix)
                    try? fileManager.removeItem(at: to)
                    guard suffix.isEmpty || fileManager.fileExists(atPath: from.path) else { continue }
                    try fileManager.copyItem(at: from, to: to)
                }
                if Self.signature(source) == before { steady = true; break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            guard steady else {
                throw WhatsAppError.busy("still changing after \(Self.attempts) copies — try again")
            }
        } catch let error as WhatsAppError {
            try? fileManager.removeItem(at: folder)
            throw error
        } catch {
            try? fileManager.removeItem(at: folder)
            if PermissionCheck.isRefusal(error) { throw WhatsAppError.notPermitted(source.path) }
            throw WhatsAppError.readFailed(error.localizedDescription)
        }

        do {
            database = try SQLiteDatabase(path: target.path)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

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
