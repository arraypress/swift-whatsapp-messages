//
//  Fixture.swift
//  WhatsAppMessagesTests
//
//  Created by David Sherlock on 2026.
//
//  A WhatsApp container built from nothing. Nobody's messages: every name
//  is a historical figure, every number is in Ofcom's drama range
//  (07700 900xxx), every `@lid` id is made up, and the tables are created
//  with the same DDL WhatsApp for Mac 26.40 (model 2.12.14) uses — copied
//  from `sqlite_master`, which holds the shape and nothing else.
//

import Foundation
import SQLite3
@testable import WhatsAppMessages

/// A SQLite file the tests write — the only kind of SQLite they write.
final class FixtureDatabase {

    let handle: OpaquePointer

    init(path: String, wal: Bool = true) {
        var pointer: OpaquePointer?
        precondition(sqlite3_open(path, &pointer) == SQLITE_OK)
        handle = pointer!
        if wal { exec("PRAGMA journal_mode=WAL") }
    }

    deinit { sqlite3_close(handle) }

    func exec(_ sql: String) {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            fatalError("fixture SQL failed: \(String(cString: error!)) in \(sql)")
        }
    }

    /// Inserts one row; `nil` binds NULL.
    func insert(_ table: String, _ values: [String: Any?]) {
        let columns = values.keys.sorted()
        let sql = "insert into \(table) (\(columns.joined(separator: ","))) values (\(columns.map { _ in "?" }.joined(separator: ",")))"
        var statement: OpaquePointer?
        precondition(sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, String(cString: sqlite3_errmsg(handle)))
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, column) in columns.enumerated() {
            let index = Int32(offset + 1)
            switch values[column] ?? nil {
            case let value as Int: sqlite3_bind_int64(statement, index, Int64(value))
            case let value as Int64: sqlite3_bind_int64(statement, index, value)
            case let value as Double: sqlite3_bind_double(statement, index, value)
            case let value as String: sqlite3_bind_text(statement, index, value, -1, transient)
            case let value as Data:
                _ = value.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(value.count), transient) }
            default: sqlite3_bind_null(statement, index)
            }
        }
        precondition(sqlite3_step(statement) == SQLITE_DONE, String(cString: sqlite3_errmsg(handle)))
    }
}

/// The synthetic people and chats.
enum People {
    static let adaPhone = "447700900123@s.whatsapp.net"
    static let adaLID = "100000000000001@lid"
    static let charlesLID = "100000000000002@lid"
    static let charlesPhone = "447700900456@s.whatsapp.net"
    static let hiddenPhone = "447700900789@s.whatsapp.net"
    static let graceLID = "100000000000009@lid"
    /// A made-up `@lid` id whose digits END like Ada's number — the case
    /// where comparing an `@lid` id as a phone number would go wrong.
    static let decoyLID = "990447700900123@lid"
    static let group = "120363000000000001@g.us"
    static let status = "status@broadcast"
}

/// 1 October 2026, 10:00 UTC, in Core Data seconds.
let fixtureEpoch: Double = 812_541_600

enum Fixture {

    static let chatDDL = [
        "CREATE TABLE ZWACHATSESSION ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZARCHIVED INTEGER, ZCONTACTABID INTEGER, ZFLAGS INTEGER, ZHIDDEN INTEGER, ZIDENTITYVERIFICATIONEPOCH INTEGER, ZIDENTITYVERIFICATIONSTATE INTEGER, ZMESSAGECOUNTER INTEGER, ZREMOVED INTEGER, ZSESSIONTYPE INTEGER, ZSPOTLIGHTSTATUS INTEGER, ZUNREADCOUNT INTEGER, ZGROUPINFO INTEGER, ZLASTMESSAGE INTEGER, ZPROPERTIES INTEGER, ZLASTMESSAGEDATE TIMESTAMP, ZLOCATIONSHARINGENDDATE TIMESTAMP, ZCONTACTIDENTIFIER VARCHAR, ZCONTACTJID VARCHAR, ZETAG VARCHAR, ZLASTMESSAGETEXT VARCHAR, ZPARTNERNAME VARCHAR, ZSAVEDINPUT VARCHAR )",
        "CREATE TABLE ZWAGROUPINFO ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZSTATE INTEGER, ZCHATSESSION INTEGER, ZLASTMESSAGEOWNER INTEGER, ZCREATIONDATE TIMESTAMP, ZSUBJECTTIMESTAMP TIMESTAMP, ZCREATORJID VARCHAR, ZOWNERJID VARCHAR, ZPICTUREID VARCHAR, ZPICTUREPATH VARCHAR, ZSOURCEJID VARCHAR, ZSUBJECTOWNERJID VARCHAR )",
        "CREATE TABLE ZWAGROUPMEMBER ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCONTACTABID INTEGER, ZISACTIVE INTEGER, ZISADMIN INTEGER, ZSENDERKEYSENT INTEGER, ZCHATSESSION INTEGER, ZRECENTGROUPCHAT INTEGER, ZCONTACTIDENTIFIER VARCHAR, ZCONTACTNAME VARCHAR, ZFIRSTNAME VARCHAR, ZMEMBERJID VARCHAR )",
        "CREATE TABLE ZWAMEDIAITEM ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCLOUDSTATUS INTEGER, ZFILESIZE INTEGER, ZMEDIAORIGIN INTEGER, ZMOVIEDURATION INTEGER, ZMESSAGE INTEGER, ZASPECTRATIO FLOAT, ZHACCURACY FLOAT, ZLATITUDE FLOAT, ZLONGITUDE FLOAT, ZMEDIAURLDATE TIMESTAMP, ZAUTHORNAME VARCHAR, ZCOLLECTIONNAME VARCHAR, ZMEDIALOCALPATH VARCHAR, ZMEDIAURL VARCHAR, ZTHUMBNAILLOCALPATH VARCHAR, ZTITLE VARCHAR, ZVCARDNAME VARCHAR, ZVCARDSTRING VARCHAR, ZXMPPTHUMBPATH VARCHAR, ZMEDIAKEY BLOB, ZMETADATA BLOB )",
        "CREATE TABLE ZWAMESSAGE ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCHILDMESSAGESDELIVEREDCOUNT INTEGER, ZCHILDMESSAGESPLAYEDCOUNT INTEGER, ZCHILDMESSAGESREADCOUNT INTEGER, ZDATAITEMVERSION INTEGER, ZDOCID INTEGER, ZENCRETRYCOUNT INTEGER, ZFILTEREDRECIPIENTCOUNT INTEGER, ZFLAGS INTEGER, ZGROUPEVENTTYPE INTEGER, ZISFROMME INTEGER, ZMESSAGEERRORSTATUS INTEGER, ZMESSAGESTATUS INTEGER, ZMESSAGETYPE INTEGER, ZSORT INTEGER, ZSPOTLIGHTSTATUS INTEGER, ZSTARRED INTEGER, ZCHATSESSION INTEGER, ZGROUPMEMBER INTEGER, ZLASTSESSION INTEGER, ZMEDIAITEM INTEGER, ZMESSAGEINFO INTEGER, ZPARENTMESSAGE INTEGER, ZMESSAGEDATE TIMESTAMP, ZSENTDATE TIMESTAMP, ZFROMJID VARCHAR, ZMEDIASECTIONID VARCHAR, ZPHASH VARCHAR, ZPUSHNAME VARCHAR, ZSTANZAID VARCHAR, ZTEXT VARCHAR, ZTOJID VARCHAR )",
        "CREATE TABLE ZWAMESSAGEDATAITEM ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZINDEX INTEGER, ZOWNSTHUMBNAIL INTEGER, ZTYPE INTEGER, ZMESSAGE INTEGER, ZDATE TIMESTAMP, ZCHATJID VARCHAR, ZCONTENT1 VARCHAR, ZCONTENT2 VARCHAR, ZMATCHEDTEXT VARCHAR, ZSECTIONID VARCHAR, ZSENDERJID VARCHAR, ZSUMMARY VARCHAR, ZTHUMBNAILPATH VARCHAR, ZTITLE VARCHAR )",
        "CREATE TABLE ZWAMESSAGEINFO ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZMESSAGE INTEGER, ZRECEIPTINFO BLOB )",
        "CREATE TABLE ZWAPROFILEPUSHNAME ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZJID VARCHAR, ZPUSHNAME VARCHAR )",
        "CREATE TABLE Z_METADATA (Z_VERSION INTEGER PRIMARY KEY, Z_UUID VARCHAR(255), Z_PLIST BLOB)",
    ]

    static let contactsDDL = "CREATE TABLE ZWAADDRESSBOOKCONTACT ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZDISAPPEARINGMODEDURATION INTEGER, ZPHONESTATUS INTEGER, ZSECTIONSORT INTEGER, ZSORT INTEGER, ZSOURCE INTEGER, ZSPOTLIGHTSTATUS INTEGER, ZSYNCPOLICY INTEGER, ZSYNCWITHSERVERSTATE INTEGER, ZABOUTEXPIRATIONTIMESTAMP TIMESTAMP, ZABOUTTIMESTAMP TIMESTAMP, ZDISAPPEARINGMODETIMESTAMP TIMESTAMP, ZLASTUPDATED TIMESTAMP, ZABOUTEMOJI VARCHAR, ZABOUTTEXT VARCHAR, ZBUSINESSNAME VARCHAR, ZFULLNAME VARCHAR, ZGIVENNAME VARCHAR, ZHIGHLIGHTEDNAME VARCHAR, ZIDENTIFIER VARCHAR, ZINTEROPJID VARCHAR, ZLASTNAME VARCHAR, ZLID VARCHAR, ZLIDHASH VARCHAR, ZLOCALIZEDPHONENUMBER VARCHAR, ZNOTES VARCHAR, ZPHONENUMBER VARCHAR, ZPHONENUMBERLABEL VARCHAR, ZPNHASH VARCHAR, ZSEARCHTOKENLIST VARCHAR, ZSECTIONTITLE VARCHAR, ZUNIQUEID VARCHAR, ZUSERNAME VARCHAR, ZWHATSAPPID VARCHAR, ZDEVICELIST BLOB )"

    static let lidDDL = "CREATE TABLE ZWAZACCOUNT ( Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCURRENTPHONENUMBERSHARINGSTATE INTEGER, ZSTATE INTEGER, ZUSERTYPE INTEGER, ZUSERNAMESTATE INTEGER, ZCREATEDAT TIMESTAMP, ZCOUNTRYCODE VARCHAR, ZDISPLAYNAME VARCHAR, ZIDENTIFIER VARCHAR, ZPHONENUMBER VARCHAR, ZUSERNAME VARCHAR, ZADDITIONALDATA BLOB )"

    /// A Core Data metadata plist naming a model version.
    static func metadata(version: String) -> Data {
        try! PropertyListSerialization.data(
            fromPropertyList: ["NSStoreModelVersionIdentifiers": [version], "NSStoreType": "SQLite"],
            format: .binary, options: 0)
    }

    /// Field 5 (quoted stanza) and 6 (its author), as WhatsApp stores a reply.
    static func quote(stanza: String, author: String) -> Data {
        Protobuf.encode(5, .bytes(Data(stanza.utf8))) + Protobuf.encode(6, .bytes(Data(author.utf8)))
            + Protobuf.encode(68, .bytes(Data([1, 2, 3])))
    }

    /// One reaction entry: {2: sender, 3: emoji, 4: unix ms}.
    static func reactionEntry(sender: String?, emoji: String, ms: UInt64) -> Data {
        var entry = Data()
        if let sender { entry += Protobuf.encode(2, .bytes(Data(sender.utf8))) }
        entry += Protobuf.encode(3, .bytes(Data(emoji.utf8))) + Protobuf.encode(4, .varint(ms))
        return Protobuf.encode(1, .bytes(entry))
    }

    /// A receipt-info blob with delivery noise in field 2 and reactions in 7.
    static func receipt(_ entries: [Data]) -> Data {
        Protobuf.encode(2, .bytes(Protobuf.encode(10, .bytes(Protobuf.encode(1, .varint(1)))))) + Protobuf.encode(3, .varint(1))
            + Protobuf.encode(7, .bytes(entries.reduce(Data(), +)))
    }

    static func unixMilliseconds(_ coreData: Double) -> UInt64 { UInt64((coreData + 978_307_200) * 1000) }

    /// Builds a container in a fresh temporary folder and returns it.
    ///
    /// - Parameters:
    ///   - version: the model version to record.
    ///   - dropColumn: a `table.column` to leave out, for the schema tests.
    @discardableResult
    static func make(version: String = "2.12.14", dropColumn: String? = nil) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wa-fixture-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let chat = FixtureDatabase(path: root.appendingPathComponent("ChatStorage.sqlite").path)
        for ddl in chatDDL {
            var sql = ddl
            if let drop = dropColumn {
                let parts = drop.split(separator: ".")
                if sql.contains("CREATE TABLE \(parts[0]) ") {
                    sql = sql.replacingOccurrences(of: ", \(parts[1]) VARCHAR", with: "")
                        .replacingOccurrences(of: ", \(parts[1]) INTEGER", with: "")
                }
            }
            chat.exec(sql)
        }
        chat.insert("Z_METADATA", ["Z_VERSION": 1, "Z_UUID": "FIXTURE", "Z_PLIST": metadata(version: version)])
        // A store missing a column is only ever opened, never read.
        if dropColumn == nil {
            fillChats(chat)
            fillMessages(chat)
        }

        let contacts = FixtureDatabase(path: root.appendingPathComponent("ContactsV2.sqlite").path)
        contacts.exec(contactsDDL)
        contacts.insert("ZWAADDRESSBOOKCONTACT", ["Z_PK": 1, "ZFULLNAME": "Ada Lovelace", "ZGIVENNAME": "Ada",
                                                  "ZWHATSAPPID": People.adaPhone, "ZLID": People.adaLID,
                                                  "ZPHONENUMBER": "+44 7700 900123"])

        let lid = FixtureDatabase(path: root.appendingPathComponent("LID.sqlite").path)
        lid.exec(lidDDL)
        lid.insert("ZWAZACCOUNT", ["Z_PK": 1, "ZIDENTIFIER": People.charlesLID, "ZPHONENUMBER": "447700900456"])
        lid.insert("ZWAZACCOUNT", ["Z_PK": 2, "ZIDENTIFIER": People.adaLID, "ZPHONENUMBER": "447700900123"])

        makeFiles(root)
        return root
    }

    static func fillChats(_ db: FixtureDatabase) {
        let rows: [[String: Any?]] = [
            ["Z_PK": 1, "ZCONTACTJID": People.adaPhone, "ZSESSIONTYPE": 0, "ZPARTNERNAME": "Ada L.",
             "ZLASTMESSAGEDATE": fixtureEpoch + 250, "ZUNREADCOUNT": 2, "ZARCHIVED": 0, "ZHIDDEN": 0, "ZREMOVED": 0],
            ["Z_PK": 2, "ZCONTACTJID": People.charlesLID, "ZSESSIONTYPE": 0, "ZPARTNERNAME": "Charles Babbage",
             "ZLASTMESSAGEDATE": fixtureEpoch + 310, "ZUNREADCOUNT": 0, "ZARCHIVED": 1, "ZHIDDEN": 0, "ZREMOVED": 0],
            ["Z_PK": 3, "ZCONTACTJID": People.group, "ZSESSIONTYPE": 1, "ZPARTNERNAME": "Analytical Engine",
             "ZLASTMESSAGEDATE": fixtureEpoch + 420, "ZUNREADCOUNT": 0, "ZARCHIVED": 0, "ZHIDDEN": 0, "ZREMOVED": 0],
            ["Z_PK": 4, "ZCONTACTJID": People.status, "ZSESSIONTYPE": 3, "ZPARTNERNAME": nil,
             "ZLASTMESSAGEDATE": fixtureEpoch + 50, "ZUNREADCOUNT": 0, "ZARCHIVED": 0, "ZHIDDEN": 0, "ZREMOVED": 0],
            ["Z_PK": 5, "ZCONTACTJID": People.hiddenPhone, "ZSESSIONTYPE": 0, "ZPARTNERNAME": "Mary Shelley",
             "ZLASTMESSAGEDATE": fixtureEpoch + 600, "ZUNREADCOUNT": 0, "ZARCHIVED": 0, "ZHIDDEN": 1, "ZREMOVED": 0],
            ["Z_PK": 6, "ZCONTACTJID": People.graceLID, "ZSESSIONTYPE": 0, "ZPARTNERNAME": "",
             "ZLASTMESSAGEDATE": fixtureEpoch + 500, "ZUNREADCOUNT": 0, "ZARCHIVED": 0, "ZHIDDEN": 0, "ZREMOVED": 0],
        ]
        rows.forEach { db.insert("ZWACHATSESSION", $0) }

        // Ada and Charles now, by @lid; Ada's old phone-address row, inactive.
        db.insert("ZWAGROUPMEMBER", ["Z_PK": 1, "ZCHATSESSION": 3, "ZMEMBERJID": People.adaLID, "ZISACTIVE": 1, "ZISADMIN": 1, "ZCONTACTNAME": ""])
        db.insert("ZWAGROUPMEMBER", ["Z_PK": 2, "ZCHATSESSION": 3, "ZMEMBERJID": People.charlesLID, "ZISACTIVE": 1, "ZISADMIN": 0, "ZCONTACTNAME": ""])
        db.insert("ZWAGROUPMEMBER", ["Z_PK": 3, "ZCHATSESSION": 3, "ZMEMBERJID": People.adaPhone, "ZISACTIVE": 0, "ZISADMIN": 0, "ZFIRSTNAME": "Ada"])
        db.insert("ZWAGROUPMEMBER", ["Z_PK": 4, "ZCHATSESSION": 3, "ZMEMBERJID": People.graceLID, "ZISACTIVE": 1, "ZISADMIN": 0, "ZCONTACTNAME": "Grace H."])

        db.insert("ZWAPROFILEPUSHNAME", ["Z_PK": 1, "ZJID": People.graceLID, "ZPUSHNAME": "Grace"])
        db.insert("ZWAPROFILEPUSHNAME", ["Z_PK": 2, "ZJID": People.decoyLID, "ZPUSHNAME": "Decoy"])
    }

    /// One message, with its media item and receipt info when given.
    static func message(_ db: FixtureDatabase, _ id: Int, chat: Int, type: Int = 0, fromMe: Bool = false,
                        text: String? = nil, at offset: Double, from: String? = nil, member: Int? = nil,
                        flags: Int = 0x1000000, event: Int = 2,
                        media: [String: Any?]? = nil, receipt: Data? = nil) {
        if var media {
            media["Z_PK"] = id
            media["ZMESSAGE"] = id
            db.insert("ZWAMEDIAITEM", media)
        }
        if let receipt { db.insert("ZWAMESSAGEINFO", ["Z_PK": id, "ZMESSAGE": id, "ZRECEIPTINFO": receipt]) }
        db.insert("ZWAMESSAGE", [
            "Z_PK": id, "ZCHATSESSION": chat, "ZMESSAGETYPE": type, "ZISFROMME": fromMe ? 1 : 0,
            "ZTEXT": text, "ZMESSAGEDATE": fixtureEpoch + offset, "ZSTANZAID": "STANZA\(id)",
            "ZFROMJID": fromMe ? nil : from, "ZTOJID": fromMe ? from : nil, "ZGROUPMEMBER": member,
            "ZFLAGS": flags, "ZGROUPEVENTTYPE": event, "ZSTARRED": id == 101 ? 1 : nil,
            "ZMEDIAITEM": media == nil ? nil : id, "ZMESSAGEINFO": receipt == nil ? nil : id,
        ])
    }

    static let adaFolder = "Media/\(People.adaLID)"

    static func fillMessages(_ db: FixtureDatabase) {
        let ada = People.adaPhone
        message(db, 101, chat: 1, text: "Are you at the lab?", at: 100, from: ada)
        message(db, 102, chat: 1, fromMe: true, text: "Leaving now", at: 110, from: ada, receipt: receipt([
            reactionEntry(sender: People.adaLID, emoji: "👍", ms: unixMilliseconds(fixtureEpoch + 111)),
            reactionEntry(sender: People.adaLID, emoji: "❤️", ms: unixMilliseconds(fixtureEpoch + 112)),
            reactionEntry(sender: nil, emoji: "😂", ms: unixMilliseconds(fixtureEpoch + 113)),
            reactionEntry(sender: People.charlesLID, emoji: "🔥", ms: unixMilliseconds(fixtureEpoch + 114)),
            reactionEntry(sender: People.charlesLID, emoji: "", ms: unixMilliseconds(fixtureEpoch + 115)),
        ]))
        // A newer message addressed by @lid, quoting 101.
        message(db, 103, chat: 1, text: "Bring the punch cards", at: 120, from: People.adaLID,
                media: ["ZMETADATA": quote(stanza: "STANZA101", author: ada)])
        message(db, 104, chat: 1, type: 1, at: 130, from: ada, media: [
            "ZMEDIALOCALPATH": "\(adaFolder)/a/b/IMAGE-0001.jpg", "ZFILESIZE": 2048, "ZVCARDSTRING": "image/jpeg",
            "ZTITLE": "The engine, assembled", "ZXMPPTHUMBPATH": "\(adaFolder)/a/b/IMAGE-0001.thumb",
            "ZLATITUDE": 1.5, "ZLONGITUDE": 1.5,
        ])
        message(db, 105, chat: 1, type: 3, fromMe: true, at: 140, from: ada, media: [
            "ZMEDIALOCALPATH": "\(adaFolder)/c/d/VOICE-0001.opus", "ZFILESIZE": 9000,
            "ZVCARDSTRING": "audio/ogg; codecs=opus", "ZMOVIEDURATION": 7,
        ])
        message(db, 106, chat: 1, type: 3, at: 145, from: ada, media: [
            "ZMEDIALOCALPATH": "\(adaFolder)/c/d/AUDIO-0001.mp3", "ZFILESIZE": 50000,
            "ZVCARDSTRING": "audio/mpeg", "ZMOVIEDURATION": 180,
        ])
        message(db, 107, chat: 1, type: 8, at: 150, from: ada, media: [
            "ZMEDIALOCALPATH": "\(adaFolder)/e/f/DOC-0001.pdf", "ZFILESIZE": 4096,
            "ZVCARDSTRING": "application/pdf", "ZTITLE": "Sketch of the Engine.pdf",
        ])
        message(db, 108, chat: 1, type: 14, at: 160, from: ada, media: ["ZTITLE": "placeholder title"])
        message(db, 109, chat: 1, type: 6, text: "7", at: 170, from: ada, event: 7)
        message(db, 110, chat: 1, type: 59, at: 180, from: ada, media: ["ZMETADATA": Protobuf.encode(87, .bytes(Data([8, 1])))])
        message(db, 111, chat: 1, type: 7, text: "see https://example.com/page", at: 190, from: ada,
                media: ["ZTITLE": "Example Page", "ZMETADATA": Data([0x90, 0x04, 0x00])])
        db.insert("ZWAMESSAGEDATAITEM", ["Z_PK": 1, "ZMESSAGE": 111, "ZINDEX": 0, "ZTYPE": 0,
                                         "ZCONTENT1": "https://example.com/page", "ZTITLE": "Example Page"])
        message(db, 112, chat: 1, text: "A forwarded fact", at: 200, from: ada, flags: 0x1000080)
        message(db, 113, chat: 1, type: 5, at: 210, from: ada, media: ["ZLATITUDE": 51.5, "ZLONGITUDE": -0.12])
        message(db, 114, chat: 1, type: 4, at: 220, from: ada, media: [
            "ZVCARDSTRING": "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Mary Somerville\r\nEND:VCARD",
        ])
        message(db, 115, chat: 1, type: 66, at: 230, from: ada, media: ["ZTITLE": "unknown kind"])
        message(db, 116, chat: 1, fromMe: true, text: "Café à Paris", at: 240, from: ada)
        message(db, 117, chat: 1, text: "100% sure_thing", at: 250, from: ada)
        // A link WhatsApp detected that the text does not spell out.
        db.insert("ZWAMESSAGEDATAITEM", ["Z_PK": 2, "ZMESSAGE": 117, "ZINDEX": 0, "ZTYPE": 0,
                                         "ZCONTENT1": "https://example.com/sure"])

        message(db, 201, chat: 2, text: "The difference engine", at: 300, from: People.charlesLID)
        message(db, 202, chat: 2, fromMe: true, text: "Splendid", at: 310, from: People.charlesLID)

        message(db, 301, chat: 3, text: "Hello, engine room", at: 400, from: People.group, member: 1)
        message(db, 302, chat: 3, text: "Gears ready", at: 410, from: People.group, member: 2)
        message(db, 303, chat: 3, fromMe: true, text: "On my way", at: 420, from: People.group)

        message(db, 501, chat: 5, text: "Hidden away", at: 600, from: People.hiddenPhone)
        message(db, 601, chat: 6, text: "Compiling", at: 500, from: People.graceLID)
    }

    /// Media on disk: two named files, and three nobody names — one of
    /// them an APFS clone of another — plus a hidden file to skip.
    static func makeFiles(_ root: URL) {
        let message = root.appendingPathComponent("Message", isDirectory: true)
        func write(_ relative: String, bytes: Int) {
            let url = message.appendingPathComponent(relative)
            try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try! Data((0..<bytes).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }).write(to: url)
        }
        write("\(adaFolder)/a/b/IMAGE-0001.jpg", bytes: 2048)
        write("\(adaFolder)/a/b/IMAGE-0001.thumb", bytes: 100)
        write("\(adaFolder)/e/f/DOC-0001.pdf", bytes: 4096)
        write("\(adaFolder)/x/y/ORPHAN-0001.jpg", bytes: 65536)
        write("Media/\(People.group)/x/y/ORPHAN-0003.mp4", bytes: 8192)
        write("\(adaFolder)/.DS_Store", bytes: 10)
        let original = message.appendingPathComponent("\(adaFolder)/x/y/ORPHAN-0001.jpg").path
        let clone = message.appendingPathComponent("\(adaFolder)/x/y/ORPHAN-0002.jpg").path
        precondition(copyfile(original, clone, nil, copyfile_flags_t(COPYFILE_CLONE)) == 0)
    }
}
