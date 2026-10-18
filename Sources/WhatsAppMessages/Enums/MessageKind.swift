//
//  MessageKind.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a message is.
///
/// From `ZMESSAGETYPE`. Where the meaning is not certain the code is kept
/// on ``Message/typeCode`` and the kind is ``other`` — named only where the
/// data says what it was. See ``MessageKinds`` for how each was checked.
public enum MessageKind: String, Sendable, Equatable, Codable, CodingKeyRepresentable, CaseIterable {
    case text
    case image
    case video
    /// A voice note — recorded in the app, Opus in Ogg.
    case voice
    /// An audio file somebody sent.
    case audio
    case document
    case gif
    case sticker
    case link
    case contact
    case location
    /// A call, placed or missed.
    case call
    /// Something the app wrote: a group change, an encryption notice.
    case system
    /// Deleted for everyone — the row stays, the text goes.
    case deleted
    case other

    /// Whether this is something WhatsApp did rather than something a person
    /// wrote — left out of reads unless asked for.
    public var isEvent: Bool { self == .system || self == .call }

    /// Whether messages of this kind carry a file.
    public var carriesFile: Bool {
        [.image, .video, .voice, .audio, .document, .gif, .sticker].contains(self)
    }
}
