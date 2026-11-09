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
            ZStack {
                Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture())
                HStack {
                    Text("Settings").font(.system(size: 16, weight: .semibold))
                        .allowsHitTesting(false)
                    Spacer()
                    Button {
                        NSApp.keyWindow?.performClose(nil)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(SettingsIconButtonStyle()).accessibilityLabel("Close settings")
                }.padding(.horizontal, 20)
            }.frame(height: 56)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search", text: $search).textFieldStyle(.plain)
                            .accessibilityLabel("Search settings")
                    }
                    .font(.system(size: 13)).padding(.horizontal, 11).frame(height: 36)
                    .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border)
                    }
                    .padding(.bottom, 18)
                    ForEach(sections) { item in
                        Button {
                            section = item
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: item.symbol).font(.system(size: 17))
                                    .frame(width: 20)
                                Text(item.rawValue).font(.system(size: 13))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 11).frame(height: 40)
                            .background(
                                section == item ? SettingsStyle.selection : .clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(SettingsOptionStyle())
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 16)
                .frame(width: 224)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if sections.isEmpty {
                            Text("No settings found").foregroundStyle(.secondary)
                        } else {
                            Text(section.rawValue).font(.system(size: 16, weight: .semibold))
                            switch section {
                            case .general: StartupFolderSettingsView()
                            case .appearance: AppearanceSettingsView()
                            case .search: SearchSettingsView()
                            case .shortcuts: ShortcutSettingsView()
                            }
                        }
                    }
                    .padding(.horizontal, 28).padding(.vertical, 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 920, height: 600)
        .background(SettingsStyle.surface)
        .background(SettingsWindowControls())
        .ignoresSafeArea()
        .navigationTitle("Settings")
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
            control().frame(width: 232, alignment: .trailing)
        }.frame(minHeight: 68)
    }
}

private struct StartupFolderSettingsView: View {
    @AppStorage(StartupFolderPreferences.key) private var path = ""
    private var options: [StartupFolderOption] { StartupFolderPreferences.options }
    private var choices: [SettingsChoice<String>] {
        var result = options.map { SettingsChoice(value: $0.path, title: $0.title) }
        if !options.contains(where: { $0.path == path }) {
            result.append(
                SettingsChoice(
                    value: path, title: NSString(string: path).abbreviatingWithTildeInPath))
        }
        return result
    }
    var body: some View {
        VStack(spacing: 0) {
            PreferenceRow(title: "Open new windows to") {
                SettingsPicker(
                    title: "Open new windows to", selection: $path, choices: choices,
                    actionTitle: "Choose folder…", action: chooseFolder)
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

private struct SettingsWindowControls: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowView { WindowView() }
    func updateNSView(_ nsView: WindowView, context: Context) {}

    final class WindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window?.standardWindowButton(button)?.isHidden = true
            }
        }
    }
}
