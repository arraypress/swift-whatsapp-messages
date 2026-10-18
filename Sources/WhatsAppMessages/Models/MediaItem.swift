//
//  MediaItem.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The file a message carries, and whether it is still on this Mac.
public struct MediaItem: Sendable, Equatable, Codable {

    /// The path as WhatsApp stores it, relative to the container's
    /// `Message/` folder: `Media/<chat>/a/b/<uuid>.jpg`.
    public let relativePath: String?

    /// The full path on this Mac.
    public let path: String?

    /// Whether the file is there. WhatsApp for Mac downloads on demand and
    /// clears its cache, so most records outlive their file.
    public let exists: Bool

    /// Its size in bytes, as recorded.
    public let bytes: Int64

    /// `image/jpeg`, `audio/ogg; codecs=opus` — when recorded.
    public let mimeType: String?

    /// A document's file name.
    public let fileName: String?

    /// Length in seconds, for audio and video.
    public let duration: Int?

    /// The thumbnail, relative to `Message/`, when there is one.
    public let thumbnailPath: String?

    /// Where, for a shared location.
    public let latitude: Double?
    public let longitude: Double?

    /// The name on a shared contact card.
    public let contactName: String?

    /// A media item from its parts.
    public init(
        relativePath: String? = nil,
        path: String? = nil,
        exists: Bool = false,
        bytes: Int64 = 0,
        mimeType: String? = nil,
        fileName: String? = nil,
        duration: Int? = nil,
        thumbnailPath: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        contactName: String? = nil
    ) {
        self.relativePath = relativePath
        self.path = path
        self.exists = exists
        self.bytes = bytes
        self.mimeType = mimeType
        self.fileName = fileName
        self.duration = duration
        self.thumbnailPath = thumbnailPath
        self.latitude = latitude
        self.longitude = longitude
        self.contactName = contactName
    }
}
