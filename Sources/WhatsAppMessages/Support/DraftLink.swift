//
//  DraftLink.swift
//  WhatsAppMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The link that opens a filled-in draft in WhatsApp for Mac.
///
/// `whatsapp://send?phone=<digits>&text=<text>` — the scheme the native app
/// registers (`CFBundleURLSchemes` lists `whatsapp`). The number is digits
/// only, country code first, no `+`, as WhatsApp's own click-to-chat
/// documentation gives it. There is no form that names a group or an `@lid`
/// id, so neither can be drafted to.
enum DraftLink {

    /// The link, or `nil` for a number too short to be one.
    static func url(phone: String, text: String) -> URL? {
        let digits = phone.filter(\.isASCIIDigitCharacter)
        guard digits.count >= 7, digits.count <= 15 else { return nil }
        // Everything outside the unreserved characters escaped — `&`, `=`,
        // `+` and `#` included, which `.urlQueryAllowed` leaves alone and
        // which would cut the text short or turn into spaces.
        // ASCII only: `.alphanumerics` admits é and 名, which a URL may not
        // carry raw.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "whatsapp://send?phone=\(digits)&text=\(encoded)")
    }
}
