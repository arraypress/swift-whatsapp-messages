//
//  MediaPaths.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// WhatsApp's media paths.
///
/// Stored relative to the container's `Message/` folder, shaped
/// `Media/<chat address>/<x>/<y>/<uuid>.<ext>` — measured on every path in
/// one store, media and thumbnails alike.
enum MediaPaths {

    /// The full path for a stored relative one.
    static func absolute(_ relative: String, in messageFolder: URL) -> String {
        messageFolder.appendingPathComponent(relative).path
    }

    /// The chat address a relative path's folder names, if it names one.
    static func folderJID(_ relative: String) -> String? {
        let parts = relative.split(separator: "/")
        guard parts.count >= 2, parts[0] == "Media", parts[1].contains("@") else { return nil }
        return String(parts[1])
    }
}
