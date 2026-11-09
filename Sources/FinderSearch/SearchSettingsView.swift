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
                Picker("Default scope", selection: $scope) {
                    ForEach(DefaultSearchScope.allCases) { scope in
                        Text(scope.title).tag(scope.rawValue)
                    }
                }.labelsHidden()
            }
            Divider()
            Text("Excluded folders and patterns").font(.system(size: 13, weight: .medium)).padding(
                .top, 28)
            VStack(spacing: 0) {
                ForEach(rules, id: \.self) { rule in
                    HStack {
                        Text(rule).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            rules.removeAll { $0 == rule }; save()
                        } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.plain).accessibilityLabel("Remove \(rule)")
                    }.padding(.vertical, 10)
                    Divider()
                }
            }.padding(.top, 8)
            HStack(spacing: 10) {
                TextField("node_modules/ or *.log", text: $pattern)
                    .textFieldStyle(.roundedBorder).onSubmit(addPattern).accessibilityLabel(
                        "Excluded pattern")
                Button("Add", action: addPattern).disabled(
                    pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: chooseFolders) { Image(systemName: "folder.badge.plus") }
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
