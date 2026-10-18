//
//  SchemaCheck.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Whether the store still has the shape this library reads.
///
/// The schema is WhatsApp's, undocumented, and changes with the app. Two
/// checks: the model version Core Data records, which says whether this
/// exact shape was checked, and the columns themselves, which say whether
/// it can be read at all. A new version with every column is read, with a
/// warning; a missing column is refused by name rather than failing in the
/// middle of a query.
enum SchemaCheck {

    /// Model versions checked against a real store.
    static let knownVersions: Set<String> = ["2.12.14"]

    /// Every column the queries read, by table.
    static let required: [String: Set<String>] = [
        "ZWACHATSESSION": ["Z_PK", "ZCONTACTJID", "ZPARTNERNAME", "ZSESSIONTYPE", "ZLASTMESSAGEDATE",
                           "ZUNREADCOUNT", "ZARCHIVED", "ZHIDDEN", "ZREMOVED"],
        "ZWAMESSAGE": ["Z_PK", "ZCHATSESSION", "ZISFROMME", "ZMESSAGETYPE", "ZMESSAGEDATE", "ZTEXT",
                       "ZFROMJID", "ZTOJID", "ZGROUPMEMBER", "ZMEDIAITEM", "ZMESSAGEINFO", "ZSTANZAID",
                       "ZFLAGS", "ZSTARRED", "ZGROUPEVENTTYPE"],
        "ZWAMEDIAITEM": ["Z_PK", "ZMEDIALOCALPATH", "ZFILESIZE", "ZTHUMBNAILLOCALPATH", "ZXMPPTHUMBPATH",
                         "ZTITLE", "ZVCARDSTRING", "ZVCARDNAME", "ZMOVIEDURATION", "ZLATITUDE",
                         "ZLONGITUDE", "ZMETADATA"],
        "ZWAGROUPMEMBER": ["Z_PK", "ZCHATSESSION", "ZMEMBERJID", "ZCONTACTNAME", "ZFIRSTNAME",
                           "ZISACTIVE", "ZISADMIN"],
        "ZWAMESSAGEINFO": ["Z_PK", "ZRECEIPTINFO"],
        "ZWAPROFILEPUSHNAME": ["ZJID", "ZPUSHNAME"],
        "ZWAMESSAGEDATAITEM": ["ZMESSAGE", "ZCONTENT1", "ZTITLE"],
    ]

    /// `table.column` for each one missing, given each table's columns.
    static func missing(_ present: [String: Set<String>]) -> [String] {
        required.keys.sorted().flatMap { table in
            required[table, default: []].subtracting(present[table, default: []]).sorted().map { "\(table).\($0)" }
        }
    }

    /// The model version in a `Z_METADATA.Z_PLIST`.
    static func modelVersion(_ plist: Data?) -> String? {
        guard let plist,
              let dictionary = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let identifiers = dictionary["NSStoreModelVersionIdentifiers"] as? [Any] else { return nil }
        return identifiers.compactMap { $0 as? String }.first
    }
}
