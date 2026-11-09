import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(BrowserPreferences.defaultViewKey) private var view = "icons"
    @AppStorage(BrowserPreferences.defaultSortKey) private var sort = "Name"
    @AppStorage(BrowserPreferences.defaultAscendingKey) private var ascending = true
    @AppStorage(BrowserPreferences.rememberFoldersKey) private var remember = true
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PreferenceRow(title: "Default view") {
                Picker("Default view", selection: $view) {
                    ForEach(FileViewMode.allCases, id: \.rawValue) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }.labelsHidden()
            }
            Divider()
            PreferenceRow(title: "Sort by") {
                Picker("Sort by", selection: $sort) {
                    ForEach([FileSort.name, .modified, .size, .kind], id: \.rawValue) { value in
                        Text(value.rawValue).tag(value.rawValue)
                    }
                }.labelsHidden()
            }
            Divider()
            PreferenceRow(title: "Order") {
                Picker("Order", selection: $ascending) {
                    Text("Ascending").tag(true); Text("Descending").tag(false)
                }.labelsHidden()
            }
            Divider()
            PreferenceRow(title: "Remember folder views") {
                Toggle("Remember folder views", isOn: $remember).labelsHidden().toggleStyle(.switch)
                    .controlSize(.small)
            }
            Divider()
            Button("Reset folder views") {
                UserDefaults.standard.removeObject(forKey: BrowserPreferences.folderViewsKey)
            }.padding(.top, 24)
        }
    }
}
