import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(BrowserPreferences.defaultViewKey) private var view = "icons"
    @AppStorage(BrowserPreferences.defaultSortKey) private var sort = "Name"
    @AppStorage(BrowserPreferences.defaultAscendingKey) private var ascending = true
    @AppStorage(BrowserPreferences.rememberFoldersKey) private var remember = true
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PreferenceRow(title: "Default view") {
                SettingsPicker(
                    title: "Default view", selection: $view,
                    choices: FileViewMode.allCases.map {
                        SettingsChoice(value: $0.rawValue, title: $0.title)
                    })
            }
            Divider()
            PreferenceRow(title: "Sort by") {
                SettingsPicker(
                    title: "Sort by", selection: $sort,
                    choices: [FileSort.name, .modified, .size, .kind].map {
                        SettingsChoice(value: $0.rawValue, title: $0.rawValue)
                    })
            }
            Divider()
            PreferenceRow(title: "Order") {
                SettingsPicker(
                    title: "Order", selection: $ascending,
                    choices: [
                        SettingsChoice(value: true, title: "Ascending"),
                        SettingsChoice(value: false, title: "Descending"),
                    ])
            }
            Divider()
            PreferenceRow(title: "Remember folder views") {
                Toggle("Remember folder views", isOn: $remember).labelsHidden()
                    .toggleStyle(SettingsSwitchStyle())
            }
            Divider()
            Button("Reset folder views") {
                UserDefaults.standard.removeObject(forKey: BrowserPreferences.folderViewsKey)
            }.buttonStyle(SettingsButtonStyle()).padding(.top, 24)
        }
    }
}
