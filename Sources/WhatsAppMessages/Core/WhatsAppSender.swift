//
//  WhatsAppSender.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  The only way this library changes anything: by asking WhatsApp to.
//
//  TWO ROADS, AND THE SAFER ONE IS THE DEFAULT. A draft opens WhatsApp with
//  the text in the compose field and sends nothing — somebody reads it and
//  presses Send. Pressing Send is a second, separate call, through
//  Accessibility, the way a person would; a message that has reached
//  somebody's phone cannot be taken back. The caller chooses; this library
//  never chooses for them.
//
//  NO UNOFFICIAL PROTOCOL. Nothing here speaks to WhatsApp's servers. The
//  app's own link opens the draft, and the app's own Send button sends it —
//  the account sees a person using the app.
//

import AppAutomation
import AppKit
import Foundation

/// Drafting and sending through WhatsApp for Mac.
public enum WhatsAppSender {

    // MARK: - Draft

    /// Opens WhatsApp on a chat with a number, text filled in, NOT sent.
    ///
    /// `whatsapp://send?phone=<digits>&text=<text>`, the link the app
    /// registers. It names a person by number only: a group, or a contact
    /// known only by an `@lid` id with no number, cannot be drafted to.
    public static func draft(_ text: String, toPhone phone: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw WhatsAppError.emptyMessage }
        guard WhatsAppContainer.isAppInstalled else { throw WhatsAppError.noApp }
        guard let url = DraftLink.url(phone: phone, text: text) else { throw WhatsAppError.noPhoneNumber(phone) }
        guard NSWorkspace.shared.open(url) else { throw WhatsAppError.draftFailed("the whatsapp: link was refused") }
    }

    // MARK: - Send

    /// What pressing Send found and did.
    public struct Press: Sendable, Equatable {
        /// How the button was identified: its `AXIdentifier`, or its label.
        public let button: String
        /// How long the draft took to appear in the compose field.
        public let waited: TimeInterval
    }

    /// Presses Send on a draft holding exactly `text`.
    ///
    /// Waits for WhatsApp's compose field to hold the text — the draft link
    /// fills it a moment after the app comes forward — then presses the Send
    /// button through Accessibility. Refuses rather than presses when:
    ///
    /// - the field holds anything other than exactly `text` — WhatsApp keeps a
    ///   half-written draft per chat, and the link adds to it; pressing would
    ///   send words nobody asked this to send;
    /// - no single enabled Send button can be found.
    ///
    /// Either refusal leaves the draft open for a person. Pressing is not
    /// sending — confirm it by finding the message in the store.
    ///
    /// - Parameter timeout: how long to wait for the draft.
    @discardableResult
    public static func pressSend(expecting text: String, timeout: TimeInterval = 8) throws -> Press {
        guard Automation.isTrusted else { throw WhatsAppError.accessibilityNotPermitted }
        let started = Date()
        let session = try AppSession(Automation.app(matching: WhatsAppContainer.bundleIdentifier))

        var field: Element?
        var elements: [Element] = []
        while Date().timeIntervalSince(started) < timeout {
            elements = (try? session.snapshot(.allWindows).elements) ?? []
            field = Composer.field(in: elements)
            if let field, Composer.holds(field, exactly: text) { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        guard let field else { throw WhatsAppError.sendNotPressed("WhatsApp's compose field did not appear") }
        guard Composer.holds(field, exactly: text) else {
            throw WhatsAppError.sendNotPressed("the compose field holds other text as well — an earlier draft in that chat")
        }
        guard let button = Composer.sendButton(in: elements) else {
            throw WhatsAppError.sendNotPressed("no Send button was found beside the draft")
        }
        try session.press(button.ref)
        return Press(button: button.identifier ?? Composer.clean(button.label ?? "Send"),
                     waited: Date().timeIntervalSince(started))
    }
}
