//
//  DecodingTests.swift
//  WhatsAppMessagesTests
//
//  Created by David Sherlock on 2026.
//
//  The rules that decide what a row means. Every value is built here.
//

import AppAutomation
import XCTest
@testable import WhatsAppMessages

final class ProtobufTests: XCTestCase {

    func testFieldsRoundTrip() throws {
        let data = Protobuf.encode(5, .bytes(Data("abc".utf8))) + Protobuf.encode(150, .varint(300))
            + Protobuf.encode(9, .fixed64(7)) + Protobuf.encode(10, .fixed32(9))
        let fields = try XCTUnwrap(Protobuf.fields(data))
        XCTAssertEqual(Protobuf.string(fields, 5), "abc")
        XCTAssertEqual(Protobuf.integer(fields, 150), 300)
        XCTAssertEqual(fields.map(\.number), [5, 150, 9, 10])
        XCTAssertEqual(fields[2].value, .fixed64(7))
        XCTAssertEqual(fields[3].value, .fixed32(9))
    }

    func testMalformedBytesReadAsNothing() {
        // A length running past the end — another app's bytes are not trusted.
        XCTAssertNil(Protobuf.fields(Data([0x2a, 0x10, 0x41])))
        XCTAssertNil(Protobuf.fields(Data([0x2a, 0xff])))
        XCTAssertNil(Protobuf.fields(Data([0x00, 0x00])), "field number 0")
        XCTAssertNil(Protobuf.fields(Data([0x0b])), "a group start, not used here")
        XCTAssertNil(BlobDecoding.quote(Data([0x2a, 0x10, 0x41])))
        XCTAssertEqual(BlobDecoding.reactions(Data([0x3a, 0x05, 0x0a])), [])
    }
}

final class BlobTests: XCTestCase {

    func testQuotesAreFieldsFiveAndSix() {
        let blob = Fixture.quote(stanza: "3EB0ABC", author: "100@lid")
        XCTAssertEqual(BlobDecoding.quote(blob)?.stanzaID, "3EB0ABC")
        XCTAssertEqual(BlobDecoding.quote(blob)?.author, "100@lid")
        XCTAssertNil(BlobDecoding.quote(Protobuf.encode(6, .bytes(Data("x@lid".utf8)))), "an author with no stanza is no quote")
        XCTAssertNil(BlobDecoding.quote(nil))
    }

    func testTheLatestReactionPerPersonStands() {
        let receipt = Fixture.receipt([
            Fixture.reactionEntry(sender: "a@lid", emoji: "👍", ms: 2),
            Fixture.reactionEntry(sender: "a@lid", emoji: "❤️", ms: 3),
            Fixture.reactionEntry(sender: "a@lid", emoji: "😮", ms: 1),
        ])
        XCTAssertEqual(BlobDecoding.reactions(receipt).map(\.emoji), ["❤️"])
    }

    func testATakenBackReactionIsGone() {
        let receipt = Fixture.receipt([
            Fixture.reactionEntry(sender: "a@lid", emoji: "👍", ms: 2),
            Fixture.reactionEntry(sender: "a@lid", emoji: "", ms: 3),
            Fixture.reactionEntry(sender: nil, emoji: "🎉", ms: 4),
        ])
        let standing = BlobDecoding.reactions(receipt)
        XCTAssertEqual(standing.map(\.emoji), ["🎉"])
        XCTAssertNil(standing[0].sender, "no sender is your own")
    }
}

final class JIDTests: XCTestCase {

    func testKinds() {
        XCTAssertEqual(JIDs.kind("447700900123@s.whatsapp.net"), .phone)
        XCTAssertEqual(JIDs.kind("100000000000001@lid"), .lid)
        XCTAssertEqual(JIDs.kind("120363000000000001@g.us"), .group)
        XCTAssertEqual(JIDs.kind("status@broadcast"), .status)
        XCTAssertEqual(JIDs.kind("1700000000@broadcast"), .broadcast)
        XCTAssertEqual(JIDs.kind("100@lid.status"), .status)
        XCTAssertEqual(JIDs.kind("1@newsletter"), .newsletter)
        XCTAssertEqual(JIDs.kind("plain"), .other)
    }

    func testOnlyAPhoneAddressCarriesANumber() {
        XCTAssertEqual(JIDs.phone("447700900123@s.whatsapp.net"), "+447700900123")
        XCTAssertEqual(JIDs.phone("447700900123:14@s.whatsapp.net"), "+447700900123", "a device suffix is not the number")
        XCTAssertNil(JIDs.phone("447700900123@lid"), "an @lid id's digits are not a number")
        XCTAssertNil(JIDs.phone("120363000000000001@g.us"))
    }

    func testANumberAsTypedBecomesAnAddress() {
        XCTAssertEqual(JIDs.jid(forPhone: "+44 7700 900123"), "447700900123@s.whatsapp.net")
        XCTAssertNil(JIDs.jid(forPhone: "12345"))
        XCTAssertNil(JIDs.jid(forPhone: "１２３４５６７８"), "full-width digits are not ASCII digits")
    }
}

final class DirectoryTests: XCTestCase {

    let directory = ContactDirectory(
        addressBook: [People.adaPhone: "Ada Lovelace"],
        pairs: [(People.adaLID, People.adaPhone), (People.charlesLID, People.charlesPhone)],
        chatNames: [People.charlesLID: "Charles Babbage", People.adaPhone: "Ada L."],
        memberNames: [People.graceLID: "Grace H."],
        pushNames: [People.graceLID: "Grace", People.decoyLID: "Decoy"]
    )

    func testTheAddressBookWinsThenTheChatThenTheGroupThenTheirOwnName() {
        XCTAssertEqual(directory.contact(for: People.adaLID).name, "Ada Lovelace")
        XCTAssertEqual(directory.contact(for: People.adaLID).nameSource, .addressBook)
        XCTAssertEqual(directory.contact(for: People.charlesPhone).nameSource, .chat)
        XCTAssertEqual(directory.contact(for: People.graceLID).nameSource, .groupMember)
        XCTAssertEqual(directory.contact(for: People.decoyLID).nameSource, .pushName)
        XCTAssertNil(directory.contact(for: "1@lid").name)
    }

    func testPairsGoBothWays() {
        XCTAssertEqual(directory.alternate(People.adaLID), People.adaPhone)
        XCTAssertEqual(directory.alternate(People.adaPhone), People.adaLID)
        XCTAssertEqual(directory.addresses(of: People.charlesLID), [People.charlesLID, People.charlesPhone])
        XCTAssertEqual(directory.contact(for: People.charlesLID).phone, "+447700900456")
    }

    func testANumberNeverMatchesAnLidsDigits() {
        // The decoy's digits end exactly like Ada's number.
        let found = directory.resolve("07700 900123")
        XCTAssertEqual(found.map(\.jid), [People.adaPhone])
    }

    func testOnePersonIsOneAnswer() {
        XCTAssertEqual(directory.resolve("ada lovelace").map(\.jid), [People.adaPhone])
        XCTAssertEqual(directory.resolve(People.adaLID).count, 1)
    }

    func testAnUnknownNumberStillResolvesToItsAddress() {
        XCTAssertEqual(directory.resolve("+1 555 0100 999").map(\.jid), ["15550100999@s.whatsapp.net"])
        XCTAssertEqual(directory.resolve("nobody"), [])
    }

    func testPhoneShapes() {
        XCTAssertTrue(ContactDirectory.looksLikePhone("+44 (0)7700 900-123"))
        XCTAssertFalse(ContactDirectory.looksLikePhone("Ada 7700900123"))
        XCTAssertFalse(ContactDirectory.looksLikePhone("12345"))
    }
}

final class ChatMatchingTests: XCTestCase {

    let chats = [
        Chat(id: 1, jid: People.adaPhone, name: "Ada L.",
             contact: Contact(jid: People.adaPhone, alternateJID: People.adaLID, phone: "+447700900123", name: "Ada Lovelace")),
        Chat(id: 2, jid: People.charlesLID, name: "Charles Babbage",
             contact: Contact(jid: People.charlesLID, phone: "+447700900456", name: "Charles Babbage")),
        Chat(id: 3, jid: People.group, kind: .group, name: "Analytical Engine"),
        Chat(id: 4, jid: People.decoyLID, contact: Contact(jid: People.decoyLID)),
    ]

    func testIdsAndAddresses() {
        XCTAssertEqual(ChatMatching.select("3", from: chats).map(\.id), [3])
        XCTAssertEqual(ChatMatching.select(People.adaLID, from: chats).map(\.id), [1], "either of her addresses")
    }

    func testNamesExactlyThenPartly() {
        XCTAssertEqual(ChatMatching.select("ada lovelace", from: chats).map(\.id), [1])
        XCTAssertEqual(ChatMatching.select("analytical engine", from: chats).map(\.id), [3])
        XCTAssertEqual(ChatMatching.select("bab", from: chats).map(\.id), [2])
        XCTAssertEqual(ChatMatching.select("a", from: chats).map(\.id), [1, 2, 3], "two or more is for the caller to refuse")
    }

    func testANumberAsPeopleTypeIt() {
        XCTAssertEqual(ChatMatching.select("07700 900123", from: chats).map(\.id), [1])
        XCTAssertEqual(ChatMatching.select("07700 900456", from: chats).map(\.id), [2])
    }

    func testTitles() {
        XCTAssertEqual(ChatMatching.title(chats[0]), "Ada L.")
        XCTAssertEqual(ChatMatching.title(chats[3]), People.decoyLID)
    }
}

final class DraftTests: XCTestCase {

    func testTheLinkCarriesDigitsAndEscapedText() {
        let url = DraftLink.url(phone: "+44 7700 900123", text: "fish & chips = 2+2 #1 café 🙂")
        XCTAssertEqual(url?.absoluteString,
                       "whatsapp://send?phone=447700900123&text=fish%20%26%20chips%20%3D%202%2B2%20%231%20caf%C3%A9%20%F0%9F%99%82")
    }

    func testTooShortIsNoNumber() {
        XCTAssertNil(DraftLink.url(phone: "123", text: "x"))
        XCTAssertNil(DraftLink.url(phone: "1234567890123456", text: "x"))
    }

    func testNewlinesSurvive() {
        XCTAssertEqual(DraftLink.url(phone: "447700900123", text: "a\nb")?.absoluteString,
                       "whatsapp://send?phone=447700900123&text=a%0Ab")
    }
}

final class SmallRuleTests: XCTestCase {

    func testCoreDataSecondsAreFrom2001() {
        XCTAssertEqual(CoreDataDate.date(0), nil)
        XCTAssertEqual(CoreDataDate.date(812_541_600)?.timeIntervalSince1970, 812_541_600 + 978_307_200)
        XCTAssertEqual(CoreDataDate.date(unixMilliseconds: 1_790_848_800_500)?.timeIntervalSince1970, 1_790_848_800.5)
    }

    func testVCardNames() {
        XCTAssertEqual(VCard.formattedName("BEGIN:VCARD\nFN;CHARSET=UTF-8:Mary\n Somerville\nEND:VCARD"), "MarySomerville")
        XCTAssertEqual(VCard.formattedName("BEGIN:VCARD\r\nFN:Smith\\, John\r\nEND:VCARD"), "Smith, John")
        XCTAssertNil(VCard.formattedName("image/jpeg"))
    }

    func testModelVersionAndMissingColumns() throws {
        XCTAssertEqual(SchemaCheck.modelVersion(Fixture.metadata(version: "2.12.14")), "2.12.14")
        XCTAssertNil(SchemaCheck.modelVersion(Data("junk".utf8)))
        var present = SchemaCheck.required
        present["ZWAMEDIAITEM"]?.remove("ZMETADATA")
        XCTAssertEqual(SchemaCheck.missing(present), ["ZWAMEDIAITEM.ZMETADATA"])
        XCTAssertEqual(SchemaCheck.missing(SchemaCheck.required), [])
    }

    func testKinds() {
        XCTAssertEqual(MessageKinds.kind(type: 3, mimeType: "audio/ogg; codecs=opus"), .voice)
        XCTAssertEqual(MessageKinds.kind(type: 3, mimeType: "audio/mpeg"), .audio)
        XCTAssertEqual(MessageKinds.kind(type: 59, mimeType: nil), .call)
        XCTAssertEqual(MessageKinds.kind(type: 14, mimeType: nil), .deleted)
        XCTAssertEqual(MessageKinds.kind(type: 66, mimeType: nil), .other)
        for kind in MessageKind.allCases where kind != .other {
            for code in MessageKinds.codes(kind) {
                XCTAssertTrue(MessageKinds.namedCodes.contains(code), "\(kind) \(code)")
                XCTAssertTrue([kind, .voice, .audio].contains(MessageKinds.kind(type: code, mimeType: nil)))
            }
        }
        XCTAssertTrue(MessageKinds.isForwarded(flags: 0x1000080))
        XCTAssertFalse(MessageKinds.isForwarded(flags: 0x1000100))
    }

    func testMediaFolders() {
        XCTAssertEqual(MediaPaths.folderJID("Media/1@lid/a/b/x.jpg"), "1@lid")
        XCTAssertNil(MediaPaths.folderJID("Media/Profile/x.jpg"))
        XCTAssertNil(MediaPaths.folderJID("Other/1@lid/x.jpg"))
    }

    func testClonesAreToldFromCopies() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("wa-clone-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("a").path
        try Data(repeating: 7, count: 200_000).write(to: URL(fileURLWithPath: original))
        XCTAssertEqual(copyfile(original, folder.appendingPathComponent("clone").path, nil, copyfile_flags_t(COPYFILE_CLONE)), 0)
        XCTAssertEqual(copyfile(original, folder.appendingPathComponent("copy").path, nil, copyfile_flags_t(COPYFILE_DATA)), 0)
        let clone = try XCTUnwrap(FileClones.info(folder.appendingPathComponent("clone").path))
        let copy = try XCTUnwrap(FileClones.info(folder.appendingPathComponent("copy").path))
        XCTAssertTrue(clone.sharesAllBlocks)
        XCTAssertEqual(clone.privateBytes, 0)
        XCTAssertFalse(copy.sharesAllBlocks)
        XCTAssertGreaterThanOrEqual(copy.privateBytes, 200_000)
    }
}

final class ComposerTests: XCTestCase {

    func element(_ role: String, label: String? = nil, value: String? = nil, identifier: String? = nil,
                 enabled: Bool = true, at index: Int = 0) -> Element {
        Element(ref: ElementRef(path: [1, index], fingerprint: "0000"), depth: 1, role: role,
                label: label, value: value, identifier: identifier, isEnabled: enabled, actions: ["AXPress"])
    }

    func testTheFieldIsFoundByIdentifier() {
        let field = element("AXTextArea", label: "\u{200E}Compose message", value: "hi", identifier: Composer.fieldIdentifier)
        XCTAssertEqual(Composer.field(in: [element("AXButton", label: "x"), field]), field)
        XCTAssertNil(Composer.field(in: [field, field]), "two is not one")
    }

    func testThePressGoesOnlyWhenTheFieldHoldsExactlyTheText() {
        let draft = element("AXTextArea", value: "\u{200E}On my way\n", identifier: Composer.fieldIdentifier)
        XCTAssertTrue(Composer.holds(draft, exactly: "On my way"))
        let appended = element("AXTextArea", value: "half-written thought On my way", identifier: Composer.fieldIdentifier)
        XCTAssertFalse(Composer.holds(appended, exactly: "On my way"))
        XCTAssertFalse(Composer.holds(element("AXTextArea", identifier: Composer.fieldIdentifier), exactly: "x"))
    }

    func testTheSendButtonByIdentifierThenByLabel() {
        let byID = element("AXButton", label: "\u{200E}Send", identifier: Composer.sendIdentifier, at: 1)
        XCTAssertEqual(Composer.sendButton(in: [byID]), byID)
        let byLabel = element("AXButton", label: "\u{200E}Send", at: 2)
        XCTAssertEqual(Composer.sendButton(in: [byLabel, element("AXButton", label: "Voice message", at: 3)]), byLabel)
    }

    func testNoGuessing() {
        let disabled = element("AXButton", label: "Send", enabled: false)
        XCTAssertNil(Composer.sendButton(in: [disabled]))
        XCTAssertNil(Composer.sendButton(in: [element("AXButton", label: "Send", at: 1), element("AXButton", label: "Send", at: 2)]))
        XCTAssertNil(Composer.sendButton(in: [element("AXButton", label: "Send later", at: 1)]))
        XCTAssertNil(Composer.sendButton(in: [element("AXStaticText", label: "Send", at: 1)]))
    }
}
