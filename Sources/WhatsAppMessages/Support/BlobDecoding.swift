//
//  BlobDecoding.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The two protobuf blobs that hold replies and reactions.
///
/// Field numbers were found by structure, not by reading anybody's words:
/// across a whole store, the field whose strings matched another message's
/// `ZSTANZAID` (5,151 of 5,153) and the field whose strings were addresses.
enum BlobDecoding {

    /// The message a reply quotes, from `ZWAMEDIAITEM.ZMETADATA`: field 5 is
    /// the quoted message's stanza id, field 6 its author's address.
    /// (Published exporters read the same field 5 by byte offset.)
    static func quote(_ metadata: Data?) -> (stanzaID: String, author: String?)? {
        guard let metadata, let fields = Protobuf.fields(metadata),
              let stanza = Protobuf.string(fields, 5), !stanza.isEmpty else { return nil }
        let author = Protobuf.string(fields, 6).flatMap { $0.isEmpty ? nil : $0 }
        return (stanza, author)
    }

    /// One reaction as stored.
    struct StoredReaction: Equatable {
        let emoji: String
        /// The reactor's address; `nil` for yours.
        let sender: String?
        let unixMilliseconds: UInt64
    }

    /// Reactions, from `ZWAMESSAGEINFO.ZRECEIPTINFO`: field 7 holds them, each
    /// a repeated field 1 of {2: sender, 3: emoji, 4: Unix ms}. Measured: the
    /// sender is absent on roughly a third — your own — and every timestamp
    /// falls at or after the message's own. An empty emoji is a reaction
    /// taken back, and is dropped; a later reaction from the same person
    /// replaces an earlier one.
    static func reactions(_ receipt: Data?) -> [StoredReaction] {
        guard let receipt, let fields = Protobuf.fields(receipt) else { return [] }
        var latest: [String: StoredReaction] = [:]
        var order: [String] = []
        for container in Protobuf.messages(fields, 7) {
            guard let entries = Protobuf.fields(container) else { continue }
            for entry in Protobuf.messages(entries, 1) {
                guard let parts = Protobuf.fields(entry) else { continue }
                let sender = Protobuf.string(parts, 2).flatMap { $0.isEmpty ? nil : $0 }
                let reaction = StoredReaction(
                    emoji: Protobuf.string(parts, 3) ?? "",
                    sender: sender,
                    unixMilliseconds: Protobuf.integer(parts, 4) ?? 0
                )
                let key = sender ?? ""
                if let earlier = latest[key], earlier.unixMilliseconds > reaction.unixMilliseconds { continue }
                if latest[key] == nil { order.append(key) }
                latest[key] = reaction
            }
        }
        return order.compactMap { latest[$0] }.filter { !$0.emoji.isEmpty }
    }
}
