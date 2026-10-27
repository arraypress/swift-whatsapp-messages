//
//  StoreQueries.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//
//  The SQL the store is read with. Values are always bound.
//

import Foundation
import SQLiteReader

/// Queries against `ChatStorage.sqlite` (model 2.12.14), reading only
/// columns whose meaning was checked against a live store.
enum StoreQueries {

    /// Every conversation.
    static let chats = """
        select s.Z_PK, s.ZCONTACTJID, s.ZSESSIONTYPE, s.ZPARTNERNAME, s.ZLASTMESSAGEDATE,
               s.ZUNREADCOUNT, s.ZARCHIVED, s.ZHIDDEN, s.ZREMOVED
        from ZWACHATSESSION s
        order by s.ZLASTMESSAGEDATE desc
        """

    /// Messages per conversation — events and calls left out.
    static let messageCounts = """
        select ZCHATSESSION, count(*) from ZWAMESSAGE
        where ZMESSAGETYPE not in (\(MessageKinds.eventCodes.map(String.init).joined(separator: ",")))
        group by ZCHATSESSION
        """

    /// Current members per group.
    static let memberCounts = """
        select ZCHATSESSION, count(*) from ZWAGROUPMEMBER where ZISACTIVE = 1 group by ZCHATSESSION
        """

    /// A group's members, current first.
    static let members = """
        select ZMEMBERJID, ZISADMIN, ZISACTIVE from ZWAGROUPMEMBER
        where ZCHATSESSION = ? and ZMEMBERJID is not null
        order by ZISACTIVE desc, ZISADMIN desc, Z_PK
        """

    /// The columns ``WhatsAppStore`` reads a message from, in order.
    static let messageColumns = """
        m.Z_PK, m.ZSTANZAID, m.ZCHATSESSION, m.ZISFROMME, m.ZMESSAGETYPE, m.ZTEXT, m.ZMESSAGEDATE,
        m.ZFROMJID, gm.ZMEMBERJID, m.ZFLAGS, m.ZSTARRED, m.ZGROUPEVENTTYPE,
        i.ZMEDIALOCALPATH, i.ZFILESIZE, i.ZVCARDSTRING, i.ZTITLE, i.ZMOVIEDURATION,
        i.ZTHUMBNAILLOCALPATH, i.ZXMPPTHUMBPATH, i.ZLATITUDE, i.ZLONGITUDE, i.ZMETADATA,
        x.ZRECEIPTINFO, s.ZCONTACTJID, i.Z_PK
        """

    /// The joins every message query uses.
    static let messageJoins = """
        from ZWAMESSAGE m
        join ZWACHATSESSION s on s.Z_PK = m.ZCHATSESSION
        left join ZWAGROUPMEMBER gm on gm.Z_PK = m.ZGROUPMEMBER
        left join ZWAMEDIAITEM i on i.Z_PK = m.ZMEDIAITEM
        left join ZWAMESSAGEINFO x on x.Z_PK = m.ZMESSAGEINFO
        """

    /// Kinds whose media title is something a person wrote or named — a
    /// caption, a file name, a page title — and so is searched.
    static let searchableTitleCodes = [1, 2, 7, 8, 11]

    /// Messages for a query.
    ///
    /// - Returns: the SQL, its values, and whether the caller must still
    ///   filter and limit — when the text is not ASCII (SQLite's `like`
    ///   folds case for ASCII only) or a kind shares its code with another.
    static func messages(_ query: MessageQuery) -> (sql: String, values: [SQLiteValue], filterAfter: Bool) {
        var conditions: [String] = []
        var values: [SQLiteValue] = []
        var filterAfter = false

        if let kinds = query.kinds, !kinds.isEmpty {
            var codes = Set(kinds.flatMap(MessageKinds.codes))
            if kinds.contains(.other) {
                conditions.append("(m.ZMESSAGETYPE not in (\(MessageKinds.namedCodes.map(String.init).joined(separator: ",")))"
                                  + (codes.isEmpty ? ")" : " or m.ZMESSAGETYPE in (\(codes.sorted().map(String.init).joined(separator: ","))))"))
                codes = []
            } else {
                conditions.append("m.ZMESSAGETYPE in (\(codes.sorted().map(String.init).joined(separator: ",")))")
            }
            // Voice and audio share code 3; the MIME type tells them apart.
            if kinds.contains(.voice) != kinds.contains(.audio) { filterAfter = true }
        } else if !query.includeEvents {
            conditions.append("m.ZMESSAGETYPE not in (\(MessageKinds.eventCodes.map(String.init).joined(separator: ",")))")
        }
        if let chat = query.chatID {
            conditions.append("m.ZCHATSESSION = ?")
            values.append(.integer(chat))
        }
        if let fromMe = query.fromMe {
            conditions.append("m.ZISFROMME = ?")
            values.append(.integer(fromMe ? 1 : 0))
        }
        if let jids = query.fromJIDs {
            let marks = Array(repeating: "?", count: max(jids.count, 1)).joined(separator: ",")
            conditions.append("m.ZISFROMME = 0 and (m.ZFROMJID in (\(marks)) or gm.ZMEMBERJID in (\(marks)))")
            let bound: [SQLiteValue] = jids.isEmpty ? [.text("")] : jids.map { .text($0) }
            values.append(contentsOf: bound + bound)
        }
        if let since = query.since {
            conditions.append("m.ZMESSAGEDATE >= ?")
            values.append(.real(CoreDataDate.stored(since)))
        }
        if let until = query.until {
            conditions.append("m.ZMESSAGEDATE < ?")
            values.append(.real(CoreDataDate.stored(until)))
        }
        if let after = query.afterID {
            conditions.append("m.Z_PK > ?")
            values.append(.integer(after))
        }
        if let text = query.text, !text.isEmpty {
            let titles = "m.ZMESSAGETYPE in (\(searchableTitleCodes.map(String.init).joined(separator: ",")))"
            if text.allSatisfy(\.isASCII) {
                let pattern = "%" + escapeLike(text) + "%"
                conditions.append("(m.ZTEXT like ? escape '\\' or (\(titles) and i.ZTITLE like ? escape '\\'))")
                values.append(.text(pattern))
                values.append(.text(pattern))
            } else {
                conditions.append("(m.ZTEXT is not null or (\(titles) and i.ZTITLE is not null))")
                filterAfter = true
            }
        }

        let order = query.afterID != nil
            ? "m.Z_PK asc"
            : (query.newestFirst ? "m.ZMESSAGEDATE desc, m.Z_PK desc" : "m.ZMESSAGEDATE asc, m.Z_PK asc")
        var sql = """
            select \(messageColumns) \(messageJoins)
            \(conditions.isEmpty ? "" : "where " + conditions.joined(separator: " and "))
            order by \(order)
            """
        if !filterAfter {
            sql += " limit ?"
            values.append(.integer(Int64(max(query.limit, 0))))
        }
        return (sql, values, filterAfter)
    }

    /// `%`, `_` and the escape itself, made literal for `like … escape '\'`.
    static func escapeLike(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// One message by row.
    static let message = "select \(messageColumns) \(messageJoins) where m.Z_PK = ?"

    /// Links detected in any of a set of messages. One `?` per message.
    static func links(count: Int) -> String {
        """
        select ZMESSAGE, ZCONTENT1, ZTITLE from ZWAMESSAGEDATAITEM
        where ZMESSAGE in (\(Array(repeating: "?", count: count).joined(separator: ",")))
          and ZCONTENT1 like 'http%'
        order by ZMESSAGE, ZINDEX
        """
    }

    /// Rows for any of a set of stanza ids. One `?` per id.
    static func stanzas(count: Int) -> String {
        "select ZSTANZAID, Z_PK from ZWAMESSAGE where ZSTANZAID in (\(Array(repeating: "?", count: count).joined(separator: ",")))"
    }

    /// The newest message row — where `watch` starts.
    static let latestID = "select coalesce(max(Z_PK), 0) from ZWAMESSAGE"

    /// Every media path the store names, relative to `Message/`.
    static let referencedPaths = """
        select ZMEDIALOCALPATH from ZWAMEDIAITEM where ZMEDIALOCALPATH is not null
        union select ZTHUMBNAILLOCALPATH from ZWAMEDIAITEM where ZTHUMBNAILLOCALPATH is not null
        union select ZXMPPTHUMBPATH from ZWAMEDIAITEM where ZXMPPTHUMBPATH is not null
        union select ZTHUMBNAILPATH from ZWAMESSAGEDATAITEM where ZTHUMBNAILPATH is not null
        """

    /// The store's model version.
    static let metadata = "select Z_PLIST from Z_METADATA limit 1"

    /// Rows per type code — with the MIME type for code 3, which holds both
    /// voice notes and audio files.
    static let typeCounts = """
        select m.ZMESSAGETYPE, case when m.ZMESSAGETYPE = 3 then coalesce(i.ZVCARDSTRING, '') else '' end, count(*)
        from ZWAMESSAGE m left join ZWAMEDIAITEM i on i.Z_PK = m.ZMEDIAITEM
        group by 1, 2
        """

    /// Messages you sent.
    static let sentCount = "select count(*) from ZWAMESSAGE where ZISFROMME = 1"

    /// Every media file path a message names.
    static let mediaPaths = "select ZMEDIALOCALPATH from ZWAMEDIAITEM where ZMEDIALOCALPATH is not null"

    /// Address book: phone address, `@lid` id, names.
    static let addressBook = """
        select ZWHATSAPPID, ZLID, ZFULLNAME, ZGIVENNAME, ZLASTNAME, ZBUSINESSNAME from ZWAADDRESSBOOKCONTACT
        """

    /// `@lid` ids with the number WhatsApp holds for them.
    static let lidAccounts = """
        select ZIDENTIFIER, ZPHONENUMBER from ZWAZACCOUNT
        where ZIDENTIFIER is not null and ZPHONENUMBER is not null
        """

    /// Names on one-to-one conversations.
    static let chatNames = """
        select ZCONTACTJID, ZPARTNERNAME from ZWACHATSESSION
        where ZSESSIONTYPE = 0 and ZPARTNERNAME is not null and ZPARTNERNAME != ''
        """

    /// Names groups keep for members.
    static let memberNames = """
        select ZMEMBERJID, coalesce(nullif(ZCONTACTNAME, ''), nullif(ZFIRSTNAME, '')) from ZWAGROUPMEMBER
        where ZMEMBERJID is not null
        """

    /// Names people chose.
    static let pushNames = "select ZJID, ZPUSHNAME from ZWAPROFILEPUSHNAME where ZJID is not null"
}
