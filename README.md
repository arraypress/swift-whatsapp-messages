# Swift WhatsApp Messages

Read everything WhatsApp for Mac has stored — chats, groups, messages,
replies, reactions, media — as values, and draft or send through the app
itself.

```swift
import WhatsAppMessages

let store = try WhatsAppStore()

for chat in try store.chats().prefix(10) {
    print(chat.id, ChatMatching.title(chat), chat.kind, chat.contact?.phone ?? "")
}

for message in try store.messages(MessageQuery(chatID: 12, limit: 20)) {
    let who = message.isFromMe ? "me" : message.sender.map(ChatMatching.title) ?? "?"
    print(who, message.kind, message.text ?? "", message.reactions.map(\.emoji))
}

try WhatsAppSender.draft("On my way", toPhone: "+447700900123")   // opens a draft, sends nothing
try WhatsAppSender.pressSend(expecting: "On my way")              // presses Send on it
```

For the native app — `WhatsApp.app`, bundle `net.whatsapp.WhatsApp` — not
WhatsApp Web or the old Electron app. The `whatsapp` CLI is built on it.

## No unofficial protocol

Nothing here talks to WhatsApp's servers, and nothing logs in as you. Reading
is reading a file the app already keeps on your Mac; sending opens the app's
own `whatsapp://send` link and presses the app's own Send button, the way a
person would. There is no reverse-engineered client involved, so there is
nothing for WhatsApp to ban.

## The schema is undocumented

`ChatStorage.sqlite` is the app's private Core Data store. Its layout is
WhatsApp's, it is written down nowhere, and an app update can change it. So
the store checks every column it reads when it opens and refuses **by name**
if one is gone (`WhatsAppError.unsupportedSchema`), rather than failing
mid-query; and it reports Core Data's model version (`schema.modelVersion`),
saying whether this library was checked against it. Checked: **2.12.14**
(WhatsApp for Mac 26.40). A newer version with every column present is read,
with `schema.isKnown == false`.

## What it reads

From `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/`:

| Data | Where | How it was worked out |
|---|---|---|
| **Chats** | `ZWACHATSESSION` — address, `ZSESSIONTYPE`, name, last date, unread, archived, hidden | type 0 person, 1 group (`@g.us`), 3 status; `status@broadcast` is status |
| **Messages** | `ZWAMESSAGE` — text, date, from me, type, chat, group member | dates are Core Data **seconds** since 2001 |
| **Kinds** | `ZMESSAGETYPE` | from file types, MIME types and which columns are filled — table below |
| **Files** | `ZWAMEDIAITEM` — path under `Message/`, size, MIME (`ZVCARDSTRING`), duration, thumbnail | every path is `Media/<chat address>/x/y/<uuid>.<ext>` |
| **Captions, file names, link titles** | `ZWAMEDIAITEM.ZTITLE`, by kind | |
| **Replies** | `ZWAMEDIAITEM.ZMETADATA`, protobuf field 5 (quoted stanza id) and 6 (its author) | 5,151 of 5,153 field-5 values matched another row's `ZSTANZAID` |
| **Reactions** | `ZWAMESSAGEINFO.ZRECEIPTINFO`, protobuf field 7 → repeated 1 → {2 sender, 3 emoji, 4 Unix ms} | every emoji field held an emoji; the sender is absent on your own |
| **Forwarded** | `ZFLAGS` bit 0x80 | set on exactly the rows whose metadata carries a forwarding score |
| **Deleted for everyone** | type 14 | |
| **Links** | `ZWAMESSAGEDATAITEM` — URL and title | |
| **Group members** | `ZWAGROUPMEMBER` — address, admin, active | |
| **Names** | `ContactsV2.sqlite` (address book), `ZPARTNERNAME`, group names, `ZWAPROFILEPUSHNAME` | in that order |
| **`@lid` → number** | `LID.sqlite` `ZWAZACCOUNT`, and `ContactsV2.ZLID` | |

Message kinds, by `ZMESSAGETYPE`:

| Code | Kind | Code | Kind |
|---|---|---|---|
| 0 | text | 7 | link |
| 1 | image | 8 | document |
| 2 | video | 11 | GIF |
| 3 | voice (Opus/Ogg) or audio (anything else) | 14 | deleted |
| 4 | contact card | 15 | sticker |
| 5 | location | 59 | call |
| 6, 10 | system notice | other | `other`, with `typeCode` |

Type 59 is a call because, inside the window the app's call log covers, 113 of
131 such rows sat within five minutes of a logged call (text messages: 1.7 %).
Types 12 and 66 were seen and could not be named from structure alone, so they
are reported by code — not guessed at. **Edits** are not read: no column or
blob field could be tied to them without reading message text, which this
work did not do.

## Two addresses for one person

WhatsApp addresses a person as `447700900123@s.whatsapp.net` — the user part
is the number — or, newer, as `123456789012345@lid`, an id with no number in
it. Measured on one Mac: chats opened before the change kept their phone
address, but their newer messages arrived addressed by `@lid`, so a single
conversation holds both. And every media folder was named by the `@lid` id,
even for phone-addressed chats.

`ContactDirectory` pairs the two from WhatsApp's own tables, so a sender, a
reaction, a group member and a media folder all resolve to the same person
with the same name and number. **An `@lid` id's digits are never read as a
phone number** — one that happens to end like somebody's number is not them.

## Read from a copy, never in place

Measured on a scratch database with a writer holding it open, as WhatsApp
does: a reader opened with SQLite's `mode=ro` **still changed the `-shm`
file** — readers record their read marks there. A read-only open of
WhatsApp's store is not a read; it writes into WhatsApp's container.

So `WhatsAppStore` never opens WhatsApp's files. It clones the database and
its write-ahead log into a private temporary folder (an APFS clone copies no
data and takes milliseconds), checks that neither changed while it was
copied, reads the copy with `PRAGMA query_only`, and deletes it. That works
while WhatsApp is running, and sees messages still in the log. A store is a
snapshot; `refreshed()` takes a new one.

## Media, and media nobody names

`MediaItem.exists` says whether a file is on this Mac. Usually it is not:
WhatsApp for Mac downloads media when a chat is opened and clears its cache —
on one Mac, 12 of 1,149 named paths were present.

`mediaAudit()` walks `Message/Media` and lists files that **no** media,
thumbnail or link-preview record names, with what deleting each would free.
That number is not the file size: an APFS clone shares its blocks with
another file, and measured with `cp -c`, a clone and its original each report
a private size of 0. A folder of 72,000 clones can be large and free almost
nothing until the last copy of each goes. The audit only looks; it deletes
nothing.

## Sending

`WhatsAppSender.draft(_:toPhone:)` opens
`whatsapp://send?phone=<digits>&text=<text>` — the scheme the app registers —
and sends nothing.

`WhatsAppSender.pressSend(expecting:)` then finds the compose field through
Accessibility, by its `AXIdentifier` (`ChatBar_ComposerTextView`), waits until
it holds **exactly** the text — WhatsApp keeps a half-written draft per chat
and the link adds to it, so anything more is refused rather than sent — and
presses the Send button through
[swift-app-automation](https://github.com/arraypress/swift-app-automation),
which re-reads the element before pressing. Pressing is not sending: the
`whatsapp` CLI confirms by finding the new row in the store.

What the link can and cannot address:

- **A person with a number** — yes, including one whose chat is `@lid`, when
  WhatsApp's tables give the number.
- **A group** — no. The link takes a phone number; nothing addresses a group.
- **An `@lid` contact with no number on record** — no, for the same reason.

## Not verified

- **Pressing Send on a live draft.** The compose field and its neighbours
  were read from WhatsApp 26.40's interface; the Send button's identifier
  (`ChatBar_SendButton`) appears only while a draft has text and has not been
  read from a live draft, so a button labelled exactly "Send" is the
  fallback. No message has been sent by this code.
- **Edited messages**, and types 12 and 66 (above).

## Requirements

macOS 14+. **Full Disk Access** for whatever runs it — another app's group
container is protected, and without it the store throws `notPermitted`.
Accessibility, only to press Send.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-whatsapp-messages.git", from: "0.1.0")
```

## Licence

MIT.
