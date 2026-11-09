import AppKit
import XCTest
@testable import FinderSearch

final class StartupFolderTests: XCTestCase {
    @MainActor func testStartupFolderOverridesSavedSessionWithoutChangingOpenWindows() throws {
        let suite = "FinderSearch.startup.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let previous = root.appendingPathComponent("Previous", isDirectory: true)
        let startup = root.appendingPathComponent("Startup", isDirectory: true)
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: startup, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let existing = BrowserWorkspace(volumeLoader: { [] }, sessionDefaults: defaults)
        existing.current.navigate(previous)
        existing.newTab(previous)
        existing.saveSession()
        defaults.set(startup.path, forKey: StartupFolderPreferences.key)

        for _ in 0..<2 {
            let window = BrowserWorkspace(volumeLoader: { [] }, sessionDefaults: defaults)
            XCTAssertEqual(window.tabs.count, 1)
            XCTAssertEqual(window.current.location.path, startup.path)
            XCTAssertEqual(window.current.route, startup.path)
            XCTAssertTrue(window.current.query.isEmpty)
            XCTAssertTrue(window.current.backStack.isEmpty)
        }
        XCTAssertEqual(existing.tabs.count, 2)
        XCTAssertEqual(existing.current.location.path, previous.path)
    }

    @MainActor func testLastSessionSelectionRestoresSavedTabs() throws {
        let suite = "FinderSearch.startup.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = BrowserWorkspace(volumeLoader: { [] }, sessionDefaults: defaults)
        workspace.current.navigate(root)
        workspace.newTab(root)
        workspace.saveSession()
        defaults.set(root.path, forKey: StartupFolderPreferences.key)
        defaults.set("", forKey: StartupFolderPreferences.key)

        let restored = BrowserWorkspace(volumeLoader: { [] }, sessionDefaults: defaults)
        XCTAssertEqual(restored.tabs.count, 2)
        XCTAssertEqual(restored.current.location.path, root.path)
    }

    @MainActor func testExplicitNewTabDestinationIsIndependentOfStartupFolder() throws {
        let suite = "FinderSearch.startup.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let other = root.appendingPathComponent("Other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        defaults.set(root.path, forKey: StartupFolderPreferences.key)
        let workspace = BrowserWorkspace(volumeLoader: { [] }, sessionDefaults: defaults)
        workspace.newTab(other)
        XCTAssertEqual(workspace.current.location.path, other.path)
        XCTAssertEqual(workspace.tabs.first?.location.path, root.path)
    }
}
