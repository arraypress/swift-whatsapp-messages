//
//  WhatsAppError.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading WhatsApp's store or sending through the app.
public enum WhatsAppError: Error, Equatable, Sendable, LocalizedError {

    /// WhatsApp for Mac is not installed, and has never kept data here.
    case noApp

    /// The app's container is there, but not its chat database.
    case noDatabase(String)

    /// The database is there, but this process may not read it.
    ///
    /// Full Disk Access, almost always: another app's group container is
    /// protected, and the refusal arrives as EPERM.
    case notPermitted(String)

    /// The database stayed busy through every attempt to copy it whole.
    case busy(String)

    /// SQLite refused.
    case readFailed(String)

    /// Columns this library reads are gone — WhatsApp changed its schema.
    /// Carries the store's model version and what is missing.
    case unsupportedSchema(version: String?, missing: [String])

    /// No conversation matches.
    case noSuchChat(String)

    /// More than one conversation matches. Carries their ids.
    case ambiguousChat(String, [String])

    /// No message with that id.
    case noSuchMessage(Int64)

    /// Nothing to send.
    case emptyMessage

    /// The conversation has no phone number to address a draft to: a group,
    /// or a contact WhatsApp knows only by an `@lid` id with no number mapped.
    case noPhoneNumber(String)

    /// WhatsApp would not open the link, or could not be asked.
    case draftFailed(String)

    /// This process may not use Accessibility — needed only to press Send.
    case accessibilityNotPermitted

    /// The draft opened, but pressing Send could not be done safely: the
    /// compose field held other text, or no Send button was found. The
    /// draft is left open for a person.
    case sendNotPressed(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .noApp:
            "WhatsApp for Mac is not installed — this reads the native app's data"
        case .noDatabase(let path):
            "No WhatsApp chat database at \(path) — sign in to WhatsApp for Mac first"
        case .notPermitted(let path):
            "Not allowed to read \(path) — grant Full Disk Access to your terminal in "
                + "System Settings ▸ Privacy & Security ▸ Full Disk Access"
        case .busy(let reason):
            "WhatsApp's database kept changing while it was copied: \(reason)"
        case .readFailed(let reason):
            "Could not read the WhatsApp database: \(reason)"
        case .unsupportedSchema(let version, let missing):
            "WhatsApp's database has changed shape (model \(version ?? "unknown")): missing "
                + missing.joined(separator: ", ")
        case .noSuchChat(let what):
            "No conversation matches \(what)"
        case .ambiguousChat(let what, let ids):
            "\(what) matches \(ids.count) conversations"
        case .noSuchMessage(let id):
            "No message with id \(id)"
        case .emptyMessage:
            "Nothing to send"
        case .noPhoneNumber(let chat):
            "\(chat) has no phone number WhatsApp's link can address — groups and contacts known only by an @lid id cannot be drafted to"
        case .draftFailed(let reason):
            "WhatsApp did not open the draft: \(reason)"
        case .accessibilityNotPermitted:
            "Not allowed to press Send — grant Accessibility to your terminal in "
                + "System Settings ▸ Privacy & Security ▸ Accessibility"
        case .sendNotPressed(let reason):
            "Send was not pressed: \(reason)"
        }
    }
}
