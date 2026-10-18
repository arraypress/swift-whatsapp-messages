//
//  SchemaInfo.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What the store says about its own shape.
public struct SchemaInfo: Sendable, Equatable, Codable {

    /// Core Data's model version (`NSStoreModelVersionIdentifiers`), when
    /// the store records one: `2.12.14`.
    public let modelVersion: String?

    /// Whether this library was checked against that version. An unchecked
    /// version that still has every column is read — with a warning — rather
    /// than refused.
    public let isKnown: Bool

    /// Schema info from its parts.
    public init(modelVersion: String?, isKnown: Bool) {
        self.modelVersion = modelVersion
        self.isKnown = isKnown
    }
}
