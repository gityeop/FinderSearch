import AppKit
import SwiftUI

extension Notification.Name {
    static let editBrowserLocation = Notification.Name("editBrowserLocation")
}

enum FolderAddress {
    static func resolve(_ text: String, relativeTo folder: URL) throws -> URL {
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        let url: URL
        if let fileURL = URL(string: path), fileURL.isFileURL {
            url = fileURL.standardizedFileURL
        } else {
            url =
                URL(
                    fileURLWithPath: (path as NSString).expandingTildeInPath,
                    isDirectory: true,
                    relativeTo: URL(fileURLWithPath: folder.path, isDirectory: true)
                ).standardizedFileURL
        }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        return url
    }
}

struct BrowserAddressBar: View {
    @ObservedObject var model: SearchModel
    @State private var address = ""
    @FocusState private var focused: Bool

    private var ancestors: [URL] {
        var folders: [URL] = [], folder = model.location
        while true {
            folders.insert(folder, at: 0)
            if folder.path == "/" { return folders }
            folder.deleteLastPathComponent()
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ancestors, id: \.path) { folder in
                    Button(folder.path == "/" ? "Macintosh HD" : folder.lastPathComponent) {
                        model.navigate(folder)
                    }
                }
            } label: {
                Image(systemName: "folder")
            }
            .menuStyle(.borderlessButton).fixedSize().help("Parent folders")
            TextField("Path", text: $address)
                .textFieldStyle(.plain).font(.system(size: 12))
                .focused($focused).disabled(model.busy)
                .onSubmit { openAddress() }
                .onExitCommand {
                    address = model.location.path; focused = false
                }
                .accessibilityLabel("Folder path")
            if focused {
                Button(action: openAddress) { Image(systemName: "arrow.turn.down.left") }
                    .buttonStyle(.plain).help("Go")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) { Divider() }
        .onAppear { address = model.location.path }
        .onChange(of: model.location) { _, location in address = location.path }
        .onReceive(NotificationCenter.default.publisher(for: .editBrowserLocation)) { note in
            guard note.object as? UUID == model.id else { return }
            focused = true
            DispatchQueue.main.async {
                (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
            }
        }
    }
    private func openAddress() {
        let input = address
        Task {
            if await model.navigateToAddress(input) {
                address = model.location.path
                focused = false
            }
        }
    }
}

extension SearchModel {
    func navigateToAddress(_ input: String) async -> Bool {
        let base = location
        do {
            let folder = try await BackgroundWork.run {
                try FolderAddress.resolve(input, relativeTo: base)
            }
            navigate(folder)
            return true
        } catch {
            NSLog("FinderSearch address error: %@", error.localizedDescription)
            self.error = "Could not open that folder."
            return false
        }
    }
}
