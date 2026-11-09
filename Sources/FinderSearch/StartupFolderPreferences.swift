import Foundation

struct StartupFolderOption: Identifiable {
    let title: String
    let path: String
    var id: String { path }
}

enum StartupFolderPreferences {
    static let key = "startupFolderPath"
    static var options: [StartupFolderOption] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            StartupFolderOption(title: "Last session", path: ""),
            StartupFolderOption(title: "Home", path: home.path),
            StartupFolderOption(title: "Desktop", path: home.appendingPathComponent("Desktop").path),
            StartupFolderOption(title: "Documents", path: home.appendingPathComponent("Documents").path),
            StartupFolderOption(title: "Downloads", path: home.appendingPathComponent("Downloads").path),
            StartupFolderOption(title: "Applications", path: "/Applications"),
        ]
    }
    static func folder(in defaults: UserDefaults) -> URL? {
        let path = defaults.string(forKey: key) ?? ""
        return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
    }
}
