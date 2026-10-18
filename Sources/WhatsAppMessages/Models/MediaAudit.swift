//
//  MediaAudit.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Files under `Message/Media` set against what the database names.
public struct MediaAudit: Sendable, Equatable, Codable {

    /// Files found on disk.
    public let filesOnDisk: Int

    /// Distinct paths the database names (media and thumbnails).
    public let referencedPaths: Int

    /// Named and present.
    public let referencedPresent: Int

    /// Named and gone — normal for WhatsApp for Mac, which downloads on demand.
    public let referencedMissing: Int

    /// On disk and named by nothing.
    public let unreferenced: [UnreferencedFile]

    /// An audit from its parts.
    public init(filesOnDisk: Int, referencedPaths: Int, referencedPresent: Int,
                referencedMissing: Int, unreferenced: [UnreferencedFile]) {
        self.filesOnDisk = filesOnDisk
        self.referencedPaths = referencedPaths
        self.referencedPresent = referencedPresent
        self.referencedMissing = referencedMissing
        self.unreferenced = unreferenced
    }
}

/// A file no message names.
public struct UnreferencedFile: Sendable, Equatable, Codable {

    /// Relative to `Message/`.
    public let relativePath: String

    /// The full path.
    public let path: String

    /// Its size.
    public let bytes: Int64

    /// What deleting it alone would free. An APFS clone shares its blocks
    /// with another file, so this is 0 for one until every copy goes — see
    /// ``isClone``. `nil` when the volume does not say.
    public let privateBytes: Int64?

    /// Whether it shares all its blocks with another file.
    public let isClone: Bool

    /// The address of the chat folder it sits in (`Media/<jid>/…`).
    public let folderJID: String?

    /// The chat that folder belongs to, when one does.
    public var chatID: Int64?

    /// A file from its parts.
    public init(relativePath: String, path: String, bytes: Int64, privateBytes: Int64?,
                isClone: Bool, folderJID: String?, chatID: Int64? = nil) {
        self.relativePath = relativePath
        self.path = path
        self.bytes = bytes
        self.privateBytes = privateBytes
        self.isClone = isClone
        self.folderJID = folderJID
        self.chatID = chatID
    }
}
