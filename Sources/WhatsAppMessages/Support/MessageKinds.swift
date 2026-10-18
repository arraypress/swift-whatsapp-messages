//
//  MessageKinds.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What `ZMESSAGETYPE` and `ZFLAGS` mean.
///
/// Measured on one Mac's store (model 2.12.14), from the rows themselves —
/// file types, MIME types, which columns are filled — and never from any
/// message's words:
///
/// | code | kind | how it was checked |
/// |---|---|---|
/// | 0 | text | every row has text, no file |
/// | 1 | image | `image/jpeg`, `.jpg` |
/// | 2 | video | `video/mp4`, a duration on every row |
/// | 3 | voice / audio | `audio/ogg; codecs=opus` is a recorded voice note, `audio/mpeg` a file |
/// | 4 | contact | a vCard on the row |
/// | 5 | location | latitude and longitude |
/// | 6, 10 | system | no file, an event code |
/// | 7 | link | a link preview on every row |
/// | 8 | document | any MIME type, a file name |
/// | 11 | gif | `video/mp4`, looping |
/// | 14 | deleted | no text, no file — published exporters agree |
/// | 15 | sticker | `image/webp` |
/// | 59 | call | within the call log's window, 113 of 131 sat within 5 minutes of a logged call (text: 1.7 %) |
///
/// Anything else — 12 and 66 were seen — is ``MessageKind/other`` with its
/// code, not a guess.
enum MessageKinds {

    /// The kind a stored type code means.
    static func kind(type: Int, mimeType: String?) -> MessageKind {
        switch type {
        case 0: .text
        case 1: .image
        case 2: .video
        case 3: isVoice(mimeType) ? .voice : .audio
        case 4: .contact
        case 5: .location
        case 6, 10: .system
        case 7: .link
        case 8: .document
        case 11: .gif
        case 14: .deleted
        case 15: .sticker
        case 59: .call
        default: .other
        }
    }

    /// Whether audio is a recorded voice note: WhatsApp records Opus in Ogg.
    static func isVoice(_ mimeType: String?) -> Bool {
        mimeType?.lowercased().hasPrefix("audio/ogg") ?? false
    }

    /// The codes a kind is stored as, for filtering in SQL.
    static func codes(_ kind: MessageKind) -> [Int] {
        switch kind {
        case .text: [0]
        case .image: [1]
        case .video: [2]
        case .voice, .audio: [3]
        case .contact: [4]
        case .location: [5]
        case .system: [6, 10]
        case .link: [7]
        case .document: [8]
        case .gif: [11]
        case .deleted: [14]
        case .sticker: [15]
        case .call: [59]
        case .other: []
        }
    }

    /// Every code with a named kind — what ``MessageKind/other`` is not.
    static let namedCodes: [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 14, 15, 59]

    /// The codes left out unless events are asked for.
    static let eventCodes: [Int] = [6, 10, 59]

    /// `ZFLAGS` bit 7 (0x80): forwarded. Measured: set on exactly the 586 rows
    /// whose metadata carries a forwarding score (field 17), and on no other.
    static func isForwarded(flags: Int64) -> Bool { flags & 0x80 != 0 }

    /// A caption lives in the media record's title for these; for a document
    /// the title is its file name, for a link the page's title.
    static func captionIsTitle(_ kind: MessageKind) -> Bool {
        kind == .image || kind == .video || kind == .gif
    }
}
