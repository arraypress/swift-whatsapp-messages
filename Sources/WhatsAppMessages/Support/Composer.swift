//
//  Composer.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import AppAutomation
import Foundation

/// Finding WhatsApp's compose field and Send button in its interface.
///
/// By `AXIdentifier`, read from WhatsApp for Mac 26.40 through Accessibility:
/// the compose field is an `AXTextArea` identified `ChatBar_ComposerTextView`
/// (labelled "Compose message"); beside it sit `ChatBar_AttachMediaButton`,
/// `ChatBar_EmojiButton` and — while the field is empty —
/// `ChatBar_VoiceMessageButton`. Labels carry a leading U+200E
/// (left-to-right mark), so they are cleaned before any comparison.
enum Composer {

    /// The compose field's identifier.
    static let fieldIdentifier = "ChatBar_ComposerTextView"

    /// The Send button's identifier.
    static let sendIdentifier = "ChatBar_SendButton"

    /// The compose field, if exactly one is on screen.
    static func field(in elements: [Element]) -> Element? {
        let found = elements.filter { $0.identifier == fieldIdentifier }
        return found.count == 1 ? found[0] : nil
    }

    /// The Send button, if exactly one is on screen and enabled: by
    /// identifier, or failing that a button labelled exactly "Send".
    static func sendButton(in elements: [Element]) -> Element? {
        let byID = elements.filter { $0.identifier == sendIdentifier && $0.isEnabled }
        if byID.count == 1 { return byID[0] }
        guard byID.isEmpty else { return nil }
        let byLabel = elements.filter {
            $0.role == "AXButton" && $0.isEnabled && clean($0.label ?? "").caseInsensitiveCompare("Send") == .orderedSame
        }
        return byLabel.count == 1 ? byLabel[0] : nil
    }

    /// Whether the field holds this text and nothing else — so a press sends
    /// what was asked for, never a draft somebody had already started.
    static func holds(_ field: Element, exactly text: String) -> Bool {
        guard let value = field.value else { return false }
        return clean(value) == clean(text)
    }

    /// Text without direction marks, byte-order marks or outer whitespace.
    static func clean(_ text: String) -> String {
        text.unicodeScalars.filter { !["\u{200E}", "\u{200F}", "\u{FEFF}"].contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
