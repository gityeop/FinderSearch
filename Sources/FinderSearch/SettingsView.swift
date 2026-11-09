import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Keyboard shortcuts"
    var id: String { rawValue }
    var symbol: String { self == .general ? "slider.horizontal.3" : "keyboard" }
    var detail: String {
        self == .general ? "Choose where FinderSearch opens." : "Customize shortcuts for file actions."
    }
}

struct SettingsView: View {
    @State private var section = SettingsSection.general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings").font(.system(size: 20, weight: .semibold))
                    .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 22)
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.system(size: 13, weight: section == item ? .medium : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 10)
                            .background(
                                section == item ? Color.primary.opacity(0.07) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
                Label("FinderSearch", systemImage: "folder")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(10)
            }
            .padding(14).frame(width: 198)
            .background(Color.primary.opacity(0.025))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.rawValue).font(.system(size: 23, weight: .semibold))
                        Text(section.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Divider()
                    switch section {
                    case .general: StartupFolderSettingsView()
                    case .shortcuts: ShortcutSettingsView()
                    }
                }
                .padding(32).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 780, height: 500)
        .navigationTitle("Settings")
    }
}

private struct StartupFolderSettingsView: View {
    @AppStorage(StartupFolderPreferences.key) private var path = ""
    private let chooseFolderTag = "choose-folder"
    private var options: [StartupFolderOption] { StartupFolderPreferences.options }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Startup").font(.system(size: 13, weight: .semibold))
            HStack(spacing: 16) {
                Text("Open new windows to").font(.system(size: 13))
                Spacer(minLength: 8)
                Picker("Open new windows to", selection: Binding(
                    get: { path },
                    set: { value in
                        if value == chooseFolderTag { chooseFolder() } else { path = value }
                    }
                )) {
                    ForEach(options) { option in Text(option.title).tag(option.path) }
                    if !options.contains(where: { $0.path == path }) {
                        Text(URL(fileURLWithPath: path).lastPathComponent).tag(path)
                    }
                    Divider()
                    Text("Choose folder…").tag(chooseFolderTag)
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 190)
            }
            if !path.isEmpty {
                Label(path, systemImage: "folder")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .textSelection(.enabled).lineLimit(3)
            }
            Text(path.isEmpty
                 ? "Reopen your previous tabs, selections, and scroll positions."
                 : "Start with this folder when you launch FinderSearch or open a new window.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Changes apply to new windows. Your current windows stay as they are.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a startup folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true) }
        if panel.runModal() == .OK, let folder = panel.url { path = folder.path }
    }
}
