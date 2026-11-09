import Foundation

enum DefaultSearchScope: String, CaseIterable, Identifiable {
    case mac, folder, last
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mac: return "This Mac"
        case .folder: return "Current folder"
        case .last: return "Last used"
        }
    }
}

struct FolderViewOptions: Equatable {
    var view: FileViewMode
    var sort: FileSort
    var ascending: Bool
    var record: [String: Any] {
        ["view": view.rawValue, "sort": sort.rawValue, "ascending": ascending]
    }
}

struct BrowserPreferences: Equatable {
    static let defaultViewKey = "viewMode"
    static let defaultSortKey = "defaultSort"
    static let defaultAscendingKey = "defaultSortAscending"
    static let rememberFoldersKey = "rememberFolderViews"
    static let folderViewsKey = "folderViews.v1"
    static let searchScopeKey = "defaultSearchScope"
    static let lastScopeKey = "lastSearchScope"
    static let exclusionsKey = "searchExclusions"

    let defaultView: FileViewMode
    let defaultSort: FileSort
    let defaultAscending: Bool
    let rememberFolders: Bool
    let searchScope: DefaultSearchScope
    let lastScope: DefaultSearchScope
    let exclusions: [String]

    init(in defaults: UserDefaults?) {
        defaultView =
            FileViewMode(rawValue: defaults?.string(forKey: Self.defaultViewKey) ?? "icons")
            ?? .icons
        defaultSort =
            FileSort(rawValue: defaults?.string(forKey: Self.defaultSortKey) ?? "Name") ?? .name
        defaultAscending = defaults?.object(forKey: Self.defaultAscendingKey) as? Bool ?? true
        rememberFolders = defaults?.object(forKey: Self.rememberFoldersKey) as? Bool ?? true
        searchScope =
            DefaultSearchScope(rawValue: defaults?.string(forKey: Self.searchScopeKey) ?? "mac")
            ?? .mac
        lastScope =
            DefaultSearchScope(rawValue: defaults?.string(forKey: Self.lastScopeKey) ?? "mac")
            ?? .mac
        exclusions = defaults?.stringArray(forKey: Self.exclusionsKey) ?? []
    }
    var defaultOptions: FolderViewOptions {
        FolderViewOptions(view: defaultView, sort: defaultSort, ascending: defaultAscending)
    }
    func searchPath(for folder: URL) -> String {
        let selected = searchScope == .last ? lastScope : searchScope
        return selected == .folder ? folder.path : ""
    }
    func folderOptions(for path: String, in defaults: UserDefaults?) throws -> FolderViewOptions {
        guard rememberFolders,
            let records = defaults?.dictionary(forKey: Self.folderViewsKey),
            let record = records[path] as? [String: Any]
        else { return defaultOptions }
        guard let viewName = record["view"] as? String, let view = FileViewMode(rawValue: viewName),
            let sortName = record["sort"] as? String, let sort = FileSort(rawValue: sortName),
            let ascending = record["ascending"] as? Bool
        else { throw CocoaError(.coderReadCorrupt) }
        return FolderViewOptions(view: view, sort: sort, ascending: ascending)
    }
    static func save(_ options: FolderViewOptions, for path: String, in defaults: UserDefaults) {
        var records = defaults.dictionary(forKey: folderViewsKey) ?? [:]
        records[path] = options.record
        defaults.set(records, forKey: folderViewsKey)
    }
}

enum SearchExclusions {
    static func globs(for rules: [String]) -> [String] {
        rules.compactMap { rule in
            var pattern = rule.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pattern.isEmpty else { return nil }
            pattern = (pattern as NSString).expandingTildeInPath
            let wildcard = pattern.contains("*") || pattern.contains("?")
            if !wildcard && !pattern.hasSuffix("/") { pattern += "/" }
            if !pattern.hasPrefix("/") { pattern = "/**/" + pattern }
            let escaped = pattern.reduce(into: "") { result, character in
                if "[]{}\\".contains(character) { result.append("\\") }
                result.append(character)
            }
            return "!" + escaped
        }
    }
}
