import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", appearance = "Appearance", search = "Search", shortcuts =
        "Keyboard shortcuts"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "rectangle.grid.2x2"
        case .search: return "magnifyingglass"
        case .shortcuts: return "keyboard"
        }
    }
    var keywords: String {
        switch self {
        case .general:
            return "startup folder home desktop documents downloads applications last session"
        case .appearance:
            return
                "view icons list columns gallery sort order name modified size kind remember folder reset"
        case .search: return "scope this mac current folder last used excluded rules pattern"
        case .shortcuts: return "keyboard open rename copy path enter f2"
        }
    }
    func matches(_ text: String) -> Bool {
        (rawValue + " " + keywords).localizedCaseInsensitiveContains(text)
    }
}

struct SettingsView: View {
    @State private var section = SettingsSection.general
    @State private var search = ""
    private var sections: [SettingsSection] {
        SettingsSection.allCases.filter { search.isEmpty || $0.matches(search) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    NSApp.keyWindow?.performClose(nil)
                } label: {
                    Image(systemName: "xmark").font(.system(size: 13)).padding(4)
                }
                .buttonStyle(.plain).accessibilityLabel("Close settings")
            }.padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search", text: $search).textFieldStyle(.plain)
                    }
                    .font(.system(size: 13)).padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.1))
                    }
                    .padding(.bottom, 16)
                    ForEach(sections) { item in
                        Button {
                            section = item
                        } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10).padding(.vertical, 10)
                                .background(
                                    section == item ? Color.primary.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                    Spacer()
                }
                .padding(16).frame(width: 206)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if sections.isEmpty {
                            ContentUnavailableView.search(text: search)
                        } else {
                            Text(section.rawValue).font(.system(size: 18, weight: .semibold))
                            switch section {
                            case .general: StartupFolderSettingsView()
                            case .appearance: AppearanceSettingsView()
                            case .search: SearchSettingsView()
                            case .shortcuts: ShortcutSettingsView()
                            }
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 880, height: 580).navigationTitle("Settings")
        .onChange(of: search) { _, _ in
            if !sections.contains(section), let first = sections.first { section = first }
        }
    }
}

struct PreferenceRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: () -> Control
    var body: some View {
        HStack(spacing: 16) {
            Text(title).font(.system(size: 13))
            Spacer(minLength: 8)
            control().frame(width: 210, alignment: .trailing)
        }.padding(.vertical, 12)
    }
}

private struct StartupFolderSettingsView: View {
    @AppStorage(StartupFolderPreferences.key) private var path = ""
    private let chooseFolderTag = "choose-folder"
    private var options: [StartupFolderOption] { StartupFolderPreferences.options }
    var body: some View {
        VStack(spacing: 0) {
            PreferenceRow(title: "Open new windows to") {
                Picker(
                    "Open new windows to",
                    selection: Binding(
                        get: { path },
                        set: { value in
                            if value == chooseFolderTag { chooseFolder() } else { path = value }
                        }
                    )
                ) {
                    ForEach(options) { option in Text(option.title).tag(option.path) }
                    if !options.contains(where: { $0.path == path }) { Text(path).tag(path) }
                    Divider()
                    Text("Choose folder…").tag(chooseFolderTag)
                }.labelsHidden().pickerStyle(.menu)
            }
            Divider()
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a startup folder"; panel.prompt = "Choose"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false
        if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true) }
        if panel.runModal() == .OK, let folder = panel.url { path = folder.path }
    }
}
