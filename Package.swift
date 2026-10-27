// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-whatsapp-messages",
    platforms: [
        // macOS only, and not by choice: WhatsApp's native Mac app keeps its
        // store in a group container no third-party process reaches on iOS,
        // and pressing Send goes through the Mac's Accessibility API.
        .macOS(.v14)
    ],
    products: [
        .library(name: "WhatsAppMessages", targets: ["WhatsAppMessages"]),
    ],
    dependencies: [
        // For PhoneMatch: whether "+44 7700 900123" and "07700 900123" are
        // the same number is measured there, and is not written twice.
        .package(url: "https://github.com/arraypress/swift-contacts.git", from: "0.1.1"),
        // For pressing Send: refs that refuse when stale, presses checked —
        // the library `axe` is built on.
        .package(url: "https://github.com/arraypress/swift-app-automation.git", from: "0.1.0"),
        // For reading the stores: a private copy, never the live files.
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "WhatsAppMessages",
            dependencies: [
                .product(name: "ContactsKit", package: "swift-contacts"),
                .product(name: "AppAutomation", package: "swift-app-automation"),
                .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
            ]
        ),
        .testTarget(
            name: "WhatsAppMessagesTests",
            dependencies: [
                "WhatsAppMessages",
                .product(name: "AppAutomation", package: "swift-app-automation"),
            ]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
