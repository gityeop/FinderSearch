import AppKit
import XCTest
@testable import FinderSearch

final class ShortcutBehaviorTests: XCTestCase {
    private func key(_ characters: String, code: UInt16, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
    }

    func testDefaultAndCustomizedOpenAndRenameShortcuts() throws {
        let suite = "FinderSearch.shortcuts.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let enter = try key("\r", code: 36)
        let f2 = try key("\u{f705}", code: 120, flags: .function)
        XCTAssertEqual(BrowserShortcutAction.navigationAction(for: enter, in: defaults), .open)
        XCTAssertEqual(BrowserShortcutAction.navigationAction(for: f2, in: defaults), .rename)
        XCTAssertNil(BrowserShortcutAction.navigationAction(
            for: try key("\r", code: 36, flags: .shift), in: defaults))
        XCTAssertEqual(BrowserShortcutAction.open.shortcut(in: defaults).title, "Enter")
        XCTAssertEqual(BrowserShortcutAction.rename.shortcut(in: defaults).title, "F2")

        defaults.set("r", forKey: BrowserShortcutAction.rename.keyPreference)
        defaults.set(Int(NSEvent.ModifierFlags([.command, .shift]).rawValue),
                     forKey: BrowserShortcutAction.rename.modifiersPreference)
        defaults.set("\u{f706}", forKey: BrowserShortcutAction.open.keyPreference)
        XCTAssertNil(BrowserShortcutAction.navigationAction(for: enter, in: defaults))
        XCTAssertNil(BrowserShortcutAction.navigationAction(for: f2, in: defaults))
        XCTAssertEqual(BrowserShortcutAction.navigationAction(
            for: try key("\u{f706}", code: 99, flags: .function), in: defaults), .open)
        XCTAssertEqual(BrowserShortcutAction.navigationAction(
            for: try key("R", code: 15, flags: [.command, .shift]), in: defaults), .rename)
        XCTAssertEqual(BrowserShortcutAction.rename.shortcut(in: defaults).title, "⇧⌘R")
    }

    @MainActor func testCopyPathWritesPathsAndRenewsSuccessConfirmation() throws {
        let clipboard = FileClipboard(pasteboard: .withUniqueName())
        defer { clipboard.pasteboard.releaseGlobally() }
        let model = SearchModel()
        model.hits = ["A", "B"].map {
            Hit(path: "/fixture/\($0).txt", kind: "file", size: 0, mtime: 0, score: 0)
        }
        model.selection = Set(model.hits.map(\.path))
        model.copyPath(clipboard: clipboard)
        XCTAssertEqual(clipboard.pasteboard.string(forType: .string), "/fixture/A.txt\n/fixture/B.txt")
        let first = try XCTUnwrap(model.copyPathConfirmation)
        model.copyPath(clipboard: clipboard)
        XCTAssertNotEqual(try XCTUnwrap(model.copyPathConfirmation), first)
        XCTAssertNil(model.error)
    }

    @MainActor func testEmptySelectionDoesNotReportCopySuccess() {
        let clipboard = FileClipboard(pasteboard: .withUniqueName())
        defer { clipboard.pasteboard.releaseGlobally() }
        clipboard.pasteboard.setString("existing clipboard", forType: .string)
        let model = SearchModel()
        model.copyPath(clipboard: clipboard)
        XCTAssertNil(model.copyPathConfirmation)
        XCTAssertEqual(clipboard.pasteboard.string(forType: .string), "existing clipboard")
    }
}
