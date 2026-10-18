//
//  Container.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import AppKit
import Foundation

/// Where WhatsApp for Mac keeps things.
public enum WhatsAppContainer {

    /// The native app's bundle identifier.
    public static let bundleIdentifier = "net.whatsapp.WhatsApp"

    /// `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared`.
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.net.whatsapp.WhatsApp.shared", isDirectory: true)
    }

    /// Whether the app is installed, by LaunchServices.
    public static var isAppInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    /// The chat store in a container.
    static func chatStorage(_ container: URL) -> URL { container.appendingPathComponent("ChatStorage.sqlite") }

    /// WhatsApp's copy of the address book.
    static func contacts(_ container: URL) -> URL { container.appendingPathComponent("ContactsV2.sqlite") }

    /// The `@lid` → number table.
    static func lid(_ container: URL) -> URL { container.appendingPathComponent("LID.sqlite") }

    /// The folder media paths are relative to.
    static func messageFolder(_ container: URL) -> URL { container.appendingPathComponent("Message", isDirectory: true) }
}
