import XCTest
@testable import FinderSearch

final class PackageOpeningTests: XCTestCase {
    func testApplicationBundlesOpenAsItemsWhileOrdinaryFoldersRemainBrowsable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        for name in ["Example.app", "Example.bundle", "Example.pages", "Documents"] {
            let url = root.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let hit = try Hit.read(url)
            XCTAssertEqual(hit.kind, "dir")
            XCTAssertEqual(hit.isFolder, name == "Documents", name)
            XCTAssertEqual(hit.typeName, name == "Documents" ? "Folder" : "Application / Package")
        }
    }
}
