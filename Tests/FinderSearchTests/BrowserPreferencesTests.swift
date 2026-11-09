import AppKit
import XCTest
@testable import FinderSearch

final class BrowserPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var root: URL!
    override func setUpWithError() throws {
        suite = "FinderSearch.browser.tests." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for name in ["A", "B", "C", "Folder with spaces"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }
    @MainActor private func model(engine: PreferenceSearchEngine = PreferenceSearchEngine())
        -> SearchModel
    {
        SearchModel(engine: engine, searchDebounce: .milliseconds(1), preferences: defaults)
    }
    @MainActor private func loaded(_ model: SearchModel) async throws {
        for _ in 0..<500 {
            if !model.loading && !model.sorting { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Folder did not finish loading")
    }
    private func requested(_ engine: PreferenceSearchEngine, count: Int) async throws -> [String:
        Any]
    {
        for _ in 0..<500 {
            let requests = await engine.requests
            if requests.count >= count { return requests[count - 1] }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Search was not requested")
        return [:]
    }

    @MainActor func testDefaultsAndFolderOverridesSurviveNewModels() async throws {
        defaults.set("list", forKey: BrowserPreferences.defaultViewKey)
        defaults.set("Size", forKey: BrowserPreferences.defaultSortKey)
        defaults.set(false, forKey: BrowserPreferences.defaultAscendingKey)
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        try Data([1]).write(to: a.appendingPathComponent("tiny.txt"))
        try Data(repeating: 1, count: 100).write(to: a.appendingPathComponent("large.txt"))
        let first = model()
        first.navigate(a)
        try await loaded(first)
        XCTAssertEqual(first.viewMode, .list)
        XCTAssertEqual(first.sortedHits.map(\.name), ["large.txt", "tiny.txt"])
        first.viewMode = .gallery; first.sort = .modified; first.ascending = true
        first.navigate(b)
        XCTAssertEqual(first.viewMode, .list)
        XCTAssertEqual(first.sort, .size)
        XCTAssertFalse(first.ascending)
        let reopened = model()
        reopened.navigate(a)
        XCTAssertEqual(reopened.viewMode, .gallery)
        XCTAssertEqual(reopened.sort, .modified)
        XCTAssertTrue(reopened.ascending)
    }

    @MainActor func testGlobalDefaultsCanReplaceOrResetFolderOverrides() async throws {
        let browser = model()
        browser.navigate(root.appendingPathComponent("A"))
        browser.viewMode = .gallery; browser.sort = .size
        defaults.set("columns", forKey: BrowserPreferences.defaultViewKey)
        defaults.set(FileSort.modified.rawValue, forKey: BrowserPreferences.defaultSortKey)
        browser.reloadPreferences()
        XCTAssertEqual(browser.viewMode, .gallery)
        defaults.removeObject(forKey: BrowserPreferences.folderViewsKey)
        browser.reloadPreferences()
        XCTAssertEqual(browser.viewMode, .columns)
        XCTAssertEqual(browser.sort, .modified)
        browser.viewMode = .list
        defaults.set(false, forKey: BrowserPreferences.rememberFoldersKey)
        browser.reloadPreferences()
        XCTAssertEqual(browser.viewMode, .columns)
        browser.navigate(root.appendingPathComponent("B"))
        browser.navigate(root.appendingPathComponent("A"))
        XCTAssertEqual(browser.viewMode, .columns)
    }

    @MainActor func testLeavingSearchRestoresFolderViewAndSort() {
        let browser = model()
        browser.navigate(root.appendingPathComponent("A"))
        browser.viewMode = .columns; browser.sort = .modified; browser.ascending = false
        browser.query = "report"
        XCTAssertEqual(browser.sort, .relevance)
        browser.query = ""
        XCTAssertEqual(browser.viewMode, .columns)
        XCTAssertEqual(browser.sort, .modified)
        XCTAssertFalse(browser.ascending)
    }

    @MainActor func testLeavingSearchFromRecentsKeepsRecentOrdering() {
        let browser = model()
        browser.sidebar("recents")
        browser.query = "report"
        browser.query = ""
        XCTAssertEqual(browser.sort, .modified)
        XCTAssertFalse(browser.ascending)
    }

    @MainActor func testCurrentFolderAndLastUsedScopeReachEngine() async throws {
        defaults.set("folder", forKey: BrowserPreferences.searchScopeKey)
        let engine = PreferenceSearchEngine(), browser = model(engine: engine)
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        browser.navigate(a); browser.query = "first"; browser.submitSearch()
        let first = try await requested(engine, count: 1)
        XCTAssertEqual(first["in"] as? String, a.path)
        browser.setSearchScope("")
        let second = try await requested(engine, count: 2)
        XCTAssertNil(second["in"])
        browser.reloadPreferences()
        XCTAssertEqual(browser.scope, "", "An explicit scope must survive saving Last used")
        browser.query = ""
        defaults.set("last", forKey: BrowserPreferences.searchScopeKey)
        browser.reloadPreferences()
        browser.navigate(b); browser.query = "second"; browser.submitSearch()
        let third = try await requested(engine, count: 3)
        XCTAssertNil(third["in"])
        browser.setSearchScope(b.path)
        _ = try await requested(engine, count: 4)
        browser.query = ""; browser.navigate(a); browser.query = "third"; browser.submitSearch()
        let fifth = try await requested(engine, count: 5)
        XCTAssertEqual(fifth["in"] as? String, a.path)
    }

    @MainActor func testScopeAndExclusionsUpdateRunningSearch() async throws {
        let engine = PreferenceSearchEngine(), browser = model(engine: engine)
        browser.navigate(root); browser.query = "report ext:txt"; browser.submitSearch()
        _ = try await requested(engine, count: 1)
        defaults.set(
            ["node_modules/", ".git", "*.log", "/tmp/Build Cache", "[archive]"],
            forKey: BrowserPreferences.exclusionsKey)
        browser.reloadPreferences()
        let filtered = try await requested(engine, count: 2)
        XCTAssertEqual(filtered["q"] as? String, "report ext:txt")
        XCTAssertEqual(
            filtered["glob"] as? [String],
            [
                "!/**/node_modules/", "!/**/.git/", "!/**/*.log", "!/tmp/Build Cache/",
                "!/**/\\[archive\\]/",
            ])
        XCTAssertEqual(filtered["limit"] as? Int, 500)
        defaults.set("folder", forKey: BrowserPreferences.searchScopeKey)
        browser.reloadPreferences()
        let scoped = try await requested(engine, count: 3)
        XCTAssertEqual(scoped["in"] as? String, root.path)
    }

    @MainActor func testExcludedFoldersRemainBrowsable() async throws {
        let node = root.appendingPathComponent("A/node_modules")
        try FileManager.default.createDirectory(at: node, withIntermediateDirectories: true)
        defaults.set(["node_modules/"], forKey: BrowserPreferences.exclusionsKey)
        let browser = model()
        browser.navigate(root.appendingPathComponent("A"))
        try await loaded(browser)
        XCTAssertTrue(browser.sortedHits.contains { $0.name == "node_modules" })
        browser.navigate(node)
        XCTAssertEqual(browser.location.path, node.path)
    }

    @MainActor func testSavedPreferencesRefreshRunningModelAutomatically() async throws {
        let engine = PreferenceSearchEngine(), browser = model(engine: engine)
        browser.navigate(root)
        defaults.set("columns", forKey: BrowserPreferences.defaultViewKey)
        for _ in 0..<500 {
            if browser.viewMode == .columns { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(browser.viewMode, .columns)
        browser.query = "live"; browser.submitSearch()
        _ = try await requested(engine, count: 1)
        defaults.set(["*.log"], forKey: BrowserPreferences.exclusionsKey)
        let updated = try await requested(engine, count: 2)
        XCTAssertEqual(updated["glob"] as? [String], ["!/**/*.log"])
    }

    @MainActor func testRestoredSearchKeepsItsExplicitScope() {
        let browser = model()
        browser.navigate(root)
        browser.query = "report"
        browser.setSearchScope(root.path)
        let session = TabSession(browser)
        defaults.set("mac", forKey: BrowserPreferences.searchScopeKey)
        let restored = session.restore(preferences: defaults)
        XCTAssertEqual(restored.query, "report")
        XCTAssertEqual(restored.scope, root.path)
    }

    func testAddressAcceptsAbsoluteRelativeFileURLAndHomePaths() throws {
        let destination = root.appendingPathComponent("Folder with spaces")
        XCTAssertEqual(
            try FolderAddress.resolve(destination.path, relativeTo: root).path, destination.path)
        XCTAssertEqual(
            try FolderAddress.resolve("Folder with spaces", relativeTo: root).path, destination.path
        )
        XCTAssertEqual(
            try FolderAddress.resolve(destination.absoluteString, relativeTo: root).path,
            destination.path)
        XCTAssertEqual(try FolderAddress.resolve("..", relativeTo: destination).path, root.path)
        XCTAssertEqual(try FolderAddress.resolve("~", relativeTo: root).path, NSHomeDirectory())
    }

    @MainActor func testAddressFailureDoesNotNavigateOrChangeFolderSettings() async throws {
        let file = root.appendingPathComponent("file.txt")
        try Data().write(to: file)
        XCTAssertThrowsError(try FolderAddress.resolve(file.path, relativeTo: root))
        let browser = model()
        browser.navigate(root)
        browser.sort = .size
        let opened = await browser.navigateToAddress("missing folder")
        XCTAssertFalse(opened)
        XCTAssertEqual(browser.location.path, root.path)
        XCTAssertEqual(browser.sort, .size)
        XCTAssertEqual(browser.error, "Could not open that folder.")
    }
}

private actor PreferenceSearchEngine: SearchService {
    var requests: [[String: Any]] = []
    func request(_ fields: [String: Any]) async throws -> Reply {
        requests.append(fields)
        return Reply(
            ok: true, error: nil, hits: [], took_us: 1, entries: nil, full_disk_access: nil)
    }
}
