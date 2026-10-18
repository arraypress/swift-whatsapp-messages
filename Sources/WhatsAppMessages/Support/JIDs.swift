//
//  JIDs.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Reading WhatsApp addresses.
///
/// Two forms name a person: `447700900123@s.whatsapp.net`, whose user part
/// IS the number, and `123456789012345@lid`, WhatsApp's newer number-free id.
/// Measured on one Mac: chats opened before the change keep the phone
/// address, while their newer messages are addressed by `@lid` — so one
/// conversation holds both, and only WhatsApp's own pairing tables join them.
public enum JIDs {

    /// What kind of address this is.
    public static func kind(_ jid: String) -> JIDKind {
        guard let at = jid.lastIndex(of: "@") else { return .other }
        let user = jid[..<at]
        switch jid[jid.index(after: at)...] {
        case "s.whatsapp.net", "c.us": return .phone
        case "lid": return .lid
        case "g.us": return .group
        case "broadcast": return user == "status" ? .status : .broadcast
        case "status", "lid.status": return .status
        case "newsletter": return .newsletter
        default: return .other
        }
    }

    /// The part before `@`, without a device suffix (`4477…:12@…` → `4477…`).
    public static func user(_ jid: String) -> String {
        let user = jid.split(separator: "@", maxSplits: 1).first.map(String.init) ?? jid
        return user.split(separator: ":", maxSplits: 1).first.map(String.init) ?? user
    }

    /// The number a PHONE address carries, as `+447700900123`. `nil` for
    /// every other kind — an `@lid` id's digits are not a number.
    public static func phone(_ jid: String) -> String? {
        guard kind(jid) == .phone else { return nil }
        let digits = user(jid)
        guard !digits.isEmpty, digits.allSatisfy(\.isASCIIDigitCharacter) else { return nil }
        return "+" + digits
    }

    /// The phone address for a number however it is written, or `nil` when it
    /// holds too few digits to be one.
    public static func jid(forPhone number: String) -> String? {
        let digits = number.filter(\.isASCIIDigitCharacter)
        guard digits.count >= 7, digits.count <= 15 else { return nil }
        return digits + "@s.whatsapp.net"
    }

    /// Whether text looks like a WhatsApp address rather than a name.
    public static func looksLikeJID(_ text: String) -> Bool {
        text.contains("@") && kind(text) != .other
    }
}

extension Character {

    /// 0–9 only — `isNumber` also accepts ²,  ٣ and the like.
    var isASCIIDigitCharacter: Bool { isASCII && isNumber }
}
