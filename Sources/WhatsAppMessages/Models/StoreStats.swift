//
//  StoreStats.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Counts across the whole store — no content.
public struct StoreStats: Sendable, Equatable, Codable {

    /// The store's schema, as it describes itself.
    public let schema: SchemaInfo

    /// Conversations by kind.
    public let chats: [ChatKind: Int]

    /// Messages by kind.
    public let messages: [MessageKind: Int]

    /// Messages you sent.
    public let sent: Int

    /// Messages that carry a file record, and how many of those files are on
    /// this Mac.
    public let mediaRecords: Int
    public let mediaOnDisk: Int

    /// Address-book entries and `@lid` → number pairs WhatsApp holds.
    public let addressBook: Int
    public let lidMappings: Int

    /// Stats from their parts.
    public init(schema: SchemaInfo, chats: [ChatKind: Int], messages: [MessageKind: Int], sent: Int,
                mediaRecords: Int, mediaOnDisk: Int, addressBook: Int, lidMappings: Int) {
        self.schema = schema
        self.chats = chats
        self.messages = messages
        self.sent = sent
        self.mediaRecords = mediaRecords
        self.mediaOnDisk = mediaOnDisk
        self.addressBook = addressBook
        self.lidMappings = lidMappings
    }
}
