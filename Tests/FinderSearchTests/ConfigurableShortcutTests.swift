import AppKit
import XCTest
@testable import FinderSearch

final class ConfigurableShortcutTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        let name = "FinderSearch.configurable-shortcuts." + UUID().uuidString
        let value = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { value.removePersistentDomain(forName: name) }
        return value
    }
    private func event(_ key: String, code: UInt16, flags: NSEvent.ModifierFlags = []) throws
        -> NSEvent
    {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key,
                isARepeat: false, keyCode: code))
    }

    func testDefaultsPreserveEveryExistingMenuBindingAndStableStorageKeys() throws {
        let defaults = try defaults()
        let expected: [(BrowserShortcutAction, BrowserShortcut)] = [
            (.open, BrowserShortcut("\r")), (.rename, BrowserShortcut("\u{f705}")),
            (.copyPath, BrowserShortcut("c", [.command, .shift])),
            (.newWindow, BrowserShortcut("n", .command)), (.newTab, BrowserShortcut("t", .command)),
            (.reopenClosedTab, BrowserShortcut("t", [.command, .shift])),
            (.newFolder, BrowserShortcut("n", [.command, .shift])),
            (.chooseFolder, BrowserShortcut("o", [.command, .option])),
            (.duplicate, BrowserShortcut("d", .command)),
            (.trash, BrowserShortcut("\u{7f}", .command)),
            (.info, BrowserShortcut("i", .command)), (.quickLook, BrowserShortcut("y", .command)),
            (.back, BrowserShortcut("[", .command)), (.forward, BrowserShortcut("]", .command)),
            (.enclosingFolder, BrowserShortcut("\u{f700}", .command)),
            (.editLocation, BrowserShortcut("l", .command)),
            (.goToFolder, BrowserShortcut("g", [.command, .shift])),
            (.search, BrowserShortcut("f", .command)), (.refresh, BrowserShortcut("r", .command)),
            (.showHidden, BrowserShortcut(".", [.command, .shift])),
            (.iconsView, BrowserShortcut("1", .command)),
            (.listView, BrowserShortcut("2", .command)),
            (.columnsView, BrowserShortcut("3", .command)),
            (.galleryView, BrowserShortcut("4", .command)),
            (.settings, BrowserShortcut(",", .command)),
        ]
        XCTAssertEqual(Set(expected.map(\.0)), Set(BrowserShortcutAction.allCases))
        for (action, shortcut) in expected {
            XCTAssertEqual(action.shortcut(in: defaults), shortcut, action.rawValue)
        }
        XCTAssertEqual(BrowserShortcutAction.open.keyPreference, "openShortcutKey")
        XCTAssertEqual(BrowserShortcutAction.rename.modifiersPreference, "renameShortcutModifiers")
        XCTAssertEqual(BrowserShortcutAction.copyPath.keyPreference, "copyPathShortcutKey")
        defaults.set("p", forKey: "copyPathShortcutKey")
        defaults.set(
            Int(NSEvent.ModifierFlags([.command, .option]).rawValue),
            forKey: "copyPathShortcutModifiers")
        XCTAssertEqual(
            BrowserShortcutAction.copyPath.shortcut(in: defaults),
            BrowserShortcut("p", [.command, .option]))
    }

    func testTabReassignmentUsesNewKeyAndReleasesOldKeyImmediately() throws {
        let defaults = try defaults()
        let old = try event("t", code: 17, flags: .command)
        XCTAssertEqual(TabShortcut.command(for: old, in: defaults), .new)
        try BrowserShortcutAction.newTab.assign(BrowserShortcut("\u{f708}"), in: defaults)
        XCTAssertNil(TabShortcut.command(for: old, in: defaults))
        XCTAssertEqual(
            TabShortcut.command(
                for: try event("\u{f708}", code: 96, flags: .function), in: defaults), .new)
        XCTAssertEqual(
            TabShortcut.command(
                for: try event("T", code: 17, flags: [.command, .shift]), in: defaults), .reopen)
    }

    func testChangingOpenReleasesEnterAndBothLegacyAlternates() throws {
        let defaults = try defaults()
        let enter = try event("\r", code: 36)
        let commandO = try event("o", code: 31, flags: .command)
        let commandDown = try event("\u{f701}", code: 125, flags: .command)
        for key in [enter, commandO, commandDown] {
            XCTAssertEqual(BrowserShortcutAction.navigationAction(for: key, in: defaults), .open)
        }
        XCTAssertEqual(
            BrowserShortcutAction.open.menuShortcut(for: BrowserShortcut("\r")),
            BrowserShortcut("o", .command))
        try BrowserShortcutAction.open.assign(BrowserShortcut("\u{f706}"), in: defaults)
        for key in [enter, commandO, commandDown] {
            XCTAssertNil(BrowserShortcutAction.navigationAction(for: key, in: defaults))
        }
        XCTAssertEqual(
            BrowserShortcutAction.navigationAction(
                for: try event("\u{f706}", code: 99), in: defaults), .open)
        XCTAssertNil(BrowserShortcutAction.open.menuShortcut(for: BrowserShortcut("\u{f706}")))
        try BrowserShortcutAction.refresh.assign(BrowserShortcut("o", .command), in: defaults)
        XCTAssertEqual(
            BrowserShortcutAction.refresh.shortcut(in: defaults), BrowserShortcut("o", .command))
    }

    func testChangingQuickLookReleasesSpaceAndOldMenuKey() throws {
        let defaults = try defaults()
        let space = try event(" ", code: 49)
        XCTAssertEqual(BrowserShortcutAction.navigationAction(for: space, in: defaults), .quickLook)
        try BrowserShortcutAction.quickLook.assign(BrowserShortcut("\u{f709}"), in: defaults)
        XCTAssertNil(BrowserShortcutAction.navigationAction(for: space, in: defaults))
        XCTAssertNil(
            BrowserShortcutAction.navigationAction(
                for: try event("y", code: 16, flags: .command), in: defaults))
        XCTAssertEqual(
            BrowserShortcutAction.navigationAction(
                for: try event("\u{f709}", code: 97), in: defaults), .quickLook)
    }

    func testConflictingBindingsAndNativeTextEditingKeysDoNotPersist() throws {
        let defaults = try defaults()
        for (shortcut, owner) in [
            (BrowserShortcut("t", .command), "New Tab"),
            (BrowserShortcut("o", .command), "Open Selected"),
            (BrowserShortcut(" "), "Quick Look"),
            (BrowserShortcut("c", .command), "Copy"),
            (BrowserShortcut("h", [.command, .shift]), "Home"),
            (BrowserShortcut("w", .command), "Close Window"),
        ] {
            let action: BrowserShortcutAction = shortcut.key == " " ? .rename : .refresh
            XCTAssertThrowsError(try action.assign(shortcut, in: defaults)) {
                XCTAssertEqual($0.localizedDescription, "Used by " + owner)
            }
            XCTAssertNil(defaults.object(forKey: action.keyPreference))
            XCTAssertNil(defaults.object(forKey: action.modifiersPreference))
        }
    }

    func testUnmodifiedReturnIsFileOnlyButFunctionKeysWorkForMenus() throws {
        let defaults = try defaults()
        XCTAssertThrowsError(
            try BrowserShortcutAction.refresh.assign(BrowserShortcut("\r"), in: defaults)
        ) {
            XCTAssertEqual($0.localizedDescription, "Include ⌘, ⌥ or ⌃")
        }
        try BrowserShortcutAction.refresh.assign(BrowserShortcut("\u{f708}"), in: defaults)
        XCTAssertEqual(
            BrowserShortcutAction.refresh.menuShortcut(for: BrowserShortcut("\u{f708}")),
            BrowserShortcut("\u{f708}"))
        XCTAssertNil(BrowserShortcutAction.rename.menuShortcut(for: BrowserShortcut("\u{f705}")))
        try BrowserShortcutAction.open.assign(BrowserShortcut("o", .command), in: defaults)
        try BrowserShortcutAction.rename.assign(BrowserShortcut("\r"), in: defaults)
        XCTAssertEqual(
            BrowserShortcutAction.navigationAction(for: try event("\r", code: 76), in: defaults),
            .rename)
    }

    func testShiftedPunctuationUsesBaseKeyForMatchingRecordingAndConflicts() throws {
        let defaults = try defaults()
        let shiftedPeriod = try event(">", code: 47, flags: [.command, .shift])
        let key = try XCTUnwrap(BrowserShortcut.key(for: shiftedPeriod))
        XCTAssertEqual(key, ".")
        let shortcut = BrowserShortcut(
            key: key, modifiers: Int(BrowserShortcut.flags(for: shiftedPeriod).rawValue))
        XCTAssertTrue(
            BrowserShortcutAction.showHidden.shortcut(in: defaults).matches(shiftedPeriod))
        try BrowserShortcutAction.showHidden.assign(shortcut, in: defaults)
        XCTAssertEqual(BrowserShortcutAction.showHidden.shortcut(in: defaults).title, "⇧⌘.")
        XCTAssertThrowsError(try BrowserShortcutAction.refresh.assign(shortcut, in: defaults)) {
            XCTAssertEqual($0.localizedDescription, "Used by Show Hidden Files")
        }
        XCTAssertNil(defaults.object(forKey: BrowserShortcutAction.refresh.keyPreference))
    }

    func testShiftedFunctionKeysKeepTheirIdentityForFileAndMenuActions() throws {
        let defaults = try defaults()
        let shiftedF2 = try event("\u{f705}", code: 120, flags: [.shift, .function])
        let fileShortcut = BrowserShortcut(
            key: try XCTUnwrap(BrowserShortcut.key(for: shiftedF2)),
            modifiers: Int(BrowserShortcut.flags(for: shiftedF2).rawValue))
        XCTAssertEqual(fileShortcut, BrowserShortcut("\u{f705}", .shift))
        try BrowserShortcutAction.rename.assign(fileShortcut, in: defaults)
        XCTAssertEqual(
            BrowserShortcutAction.navigationAction(for: shiftedF2, in: defaults), .rename)
        XCTAssertNil(BrowserShortcutAction.rename.menuShortcut(for: fileShortcut))

        let shiftedF5 = try event("\u{f708}", code: 96, flags: [.command, .shift, .function])
        let menuShortcut = BrowserShortcut(
            key: try XCTUnwrap(BrowserShortcut.key(for: shiftedF5)),
            modifiers: Int(BrowserShortcut.flags(for: shiftedF5).rawValue))
        XCTAssertEqual(menuShortcut, BrowserShortcut("\u{f708}", [.command, .shift]))
        try BrowserShortcutAction.refresh.assign(menuShortcut, in: defaults)
        XCTAssertEqual(BrowserShortcutAction.refresh.menuShortcut(for: menuShortcut), menuShortcut)
        XCTAssertTrue(BrowserShortcutAction.refresh.shortcut(in: defaults).matches(shiftedF5))
    }

    func testSpecialKeysHaveReadableNamesAndCanonicalEvents() throws {
        XCTAssertEqual(BrowserShortcut("\u{7f}", .command).title, "⌘⌫")
        XCTAssertEqual(BrowserShortcut("\u{f700}", .command).title, "⌘↑")
        XCTAssertEqual(BrowserShortcut(" ").title, "Space")
        XCTAssertEqual(BrowserShortcut("\u{f708}").title, "F5")
        XCTAssertTrue(
            BrowserShortcut("\u{7f}", .command).matches(
                try event("\u{8}", code: 51, flags: .command)))
        XCTAssertTrue(
            BrowserShortcut("\u{f700}", .command).matches(
                try event("", code: 126, flags: [.command, .function])))
        XCTAssertTrue(BrowserShortcut("\r").matches(try event("\u{3}", code: 76)))
        XCTAssertEqual(
            BrowserShortcut.nativeModifiers(
                BrowserShortcut.eventModifiers(
                    Int(NSEvent.ModifierFlags([.command, .shift, .option]).rawValue))),
            [.command, .shift, .option])
    }
}
