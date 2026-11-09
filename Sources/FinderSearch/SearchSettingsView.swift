import AppKit
import SwiftUI

struct SearchSettingsView: View {
    @AppStorage(BrowserPreferences.searchScopeKey) private var scope = "mac"
    @State private var rules =
        UserDefaults.standard.stringArray(forKey: BrowserPreferences.exclusionsKey) ?? []
    @State private var pattern = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PreferenceRow(title: "Default scope") {
                SettingsPicker(
                    title: "Default scope", selection: $scope,
                    choices: DefaultSearchScope.allCases.map {
                        SettingsChoice(value: $0.rawValue, title: $0.title)
                    })
            }
            Divider()
            Text("Excluded folders and patterns").font(
                .system(size: SettingsStyle.bodyFontSize, weight: .medium)
            )
            .padding(.top, 30)
            VStack(spacing: 0) {
                ForEach(rules, id: \.self) { rule in
                    HStack {
                        Text(rule).font(SettingsStyle.bodyFont).lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            rules.removeAll { $0 == rule }; save()
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 11))
                        }.buttonStyle(SettingsIconButtonStyle()).accessibilityLabel(
                            "Remove \(rule)")
                    }.frame(minHeight: 48)
                    Divider()
                }
            }.padding(.top, 8)
            HStack(spacing: 10) {
                TextField("node_modules/ or *.log", text: $pattern)
                    .textFieldStyle(SettingsTextFieldStyle()).onSubmit(addPattern)
                    .accessibilityLabel(
                        "Excluded pattern")
                Button("Add", action: addPattern).buttonStyle(SettingsButtonStyle()).disabled(
                    pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: chooseFolders) { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(SettingsButtonStyle())
                    .help("Add folders").accessibilityLabel("Add excluded folders")
            }.padding(.top, 16)
        }
    }
    private func addPattern() {
        let value = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        add(value); pattern = ""
    }
    private func add(_ value: String) {
        if !rules.contains(value) { rules.append(value); save() }
    }
    private func save() {
        UserDefaults.standard.set(rules, forKey: BrowserPreferences.exclusionsKey)
    }
    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "Exclude folders"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true; panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Exclude"
        if panel.runModal() == .OK { panel.urls.forEach { add($0.path) } }
    }
}
