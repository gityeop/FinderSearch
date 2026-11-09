import AppKit
import SwiftUI

enum ShortcutGroup: String, CaseIterable, Identifiable {
    case files = "Files", navigation = "Navigation", view = "View", windows = "Windows"
    var id: Self { self }
}

enum BrowserShortcutAction: String, CaseIterable, Identifiable {
    case open, rename, copyPath
    case newWindow, newTab, reopenClosedTab, newFolder, chooseFolder, duplicate, trash, info,
        quickLook
    case back, forward, enclosingFolder, editLocation, goToFolder
    case search, refresh, showHidden, iconsView, listView, columnsView, galleryView, settings

    var id: String { rawValue }
    private var definition: (title: String, group: ShortcutGroup, shortcut: BrowserShortcut) {
        switch self {
        case .open: return ("Open Selected", .files, BrowserShortcut("\r"))
        case .rename: return ("Rename", .files, BrowserShortcut("\u{f705}"))
        case .copyPath: return ("Copy Path", .files, BrowserShortcut("c", [.command, .shift]))
        case .newWindow: return ("New Window", .windows, BrowserShortcut("n", .command))
        case .newTab: return ("New Tab", .windows, BrowserShortcut("t", .command))
        case .reopenClosedTab:
            return ("Reopen Closed Tab", .windows, BrowserShortcut("t", [.command, .shift]))
        case .newFolder: return ("New Folder", .files, BrowserShortcut("n", [.command, .shift]))
        case .chooseFolder:
            return ("Open Folder", .files, BrowserShortcut("o", [.command, .option]))
        case .duplicate: return ("Duplicate", .files, BrowserShortcut("d", .command))
        case .trash: return ("Move to Trash", .files, BrowserShortcut("\u{7f}", .command))
        case .info: return ("Get Info", .files, BrowserShortcut("i", .command))
        case .quickLook: return ("Quick Look", .files, BrowserShortcut("y", .command))
        case .back: return ("Back", .navigation, BrowserShortcut("[", .command))
        case .forward: return ("Forward", .navigation, BrowserShortcut("]", .command))
        case .enclosingFolder:
            return ("Enclosing Folder", .navigation, BrowserShortcut("\u{f700}", .command))
        case .editLocation: return ("Edit Location", .navigation, BrowserShortcut("l", .command))
        case .goToFolder:
            return ("Go to Folder", .navigation, BrowserShortcut("g", [.command, .shift]))
        case .search: return ("Search", .view, BrowserShortcut("f", .command))
        case .refresh: return ("Refresh", .view, BrowserShortcut("r", .command))
        case .showHidden:
            return ("Show Hidden Files", .view, BrowserShortcut(".", [.command, .shift]))
        case .iconsView: return ("Icon View", .view, BrowserShortcut("1", .command))
        case .listView: return ("List View", .view, BrowserShortcut("2", .command))
        case .columnsView: return ("Column View", .view, BrowserShortcut("3", .command))
        case .galleryView: return ("Gallery View", .view, BrowserShortcut("4", .command))
        case .settings: return ("Settings", .windows, BrowserShortcut(",", .command))
        }
    }
    var title: String { definition.title }
    var group: ShortcutGroup { definition.group }
    var defaultShortcut: BrowserShortcut { definition.shortcut }
    var defaultKey: String { defaultShortcut.key }
    var defaultModifiers: Int { defaultShortcut.modifiers }
    var keyPreference: String { rawValue + "ShortcutKey" }
    var modifiersPreference: String { rawValue + "ShortcutModifiers" }
    var requiresFileFocus: Bool { self == .open || self == .rename || self == .quickLook }
    private var aliases: [BrowserShortcut] {
        switch self {
        case .open: return [BrowserShortcut("o", .command), BrowserShortcut("\u{f701}", .command)]
        case .quickLook: return [BrowserShortcut(" ")]
        default: return []
        }
    }
    func shortcut(in defaults: UserDefaults = .standard) -> BrowserShortcut {
        BrowserShortcut(
            key: defaults.string(forKey: keyPreference) ?? defaultKey,
            modifiers: defaults.object(forKey: modifiersPreference) as? Int ?? defaultModifiers)
    }
    func effectiveShortcuts(in defaults: UserDefaults = .standard) -> [BrowserShortcut] {
        let primary = shortcut(in: defaults)
        return [primary] + (primary == defaultShortcut ? aliases : [])
    }
    func menuShortcut(for primary: BrowserShortcut) -> BrowserShortcut? {
        if requiresFileFocus && !primary.hasCommandModifiers {
            return primary == defaultShortcut
                ? aliases.first(where: { $0.hasCommandModifiers }) : nil
        }
        return primary
    }
    func assign(_ shortcut: BrowserShortcut, in defaults: UserDefaults = .standard) throws {
        guard shortcut.key.count == 1,
            shortcut.hasCommandModifiers || shortcut.isFunctionKey
                || requiresFileFocus && BrowserShortcut.allowsUnmodified(shortcut.key)
        else { throw ShortcutAssignmentError.invalid }
        if let owner = Self.allCases.first(where: {
            $0 != self && $0.effectiveShortcuts(in: defaults).contains(shortcut)
        }) {
            throw ShortcutAssignmentError.usedBy(owner.title)
        }
        if let owner = Self.reserved.first(where: { $0.shortcut == shortcut }) {
            throw ShortcutAssignmentError.usedBy(owner.title)
        }
        defaults.set(shortcut.key, forKey: keyPreference)
        defaults.set(shortcut.modifiers, forKey: modifiersPreference)
    }
    static func navigationAction(for event: NSEvent, in defaults: UserDefaults = .standard)
        -> BrowserShortcutAction?
    {
        [.open, .rename, .quickLook].first {
            $0.effectiveShortcuts(in: defaults).contains { $0.matches(event) }
        }
    }
    static func viewAction(for mode: FileViewMode) -> Self {
        switch mode {
        case .icons: return .iconsView
        case .list: return .listView
        case .columns: return .columnsView
        case .gallery: return .galleryView
        }
    }
    private static var reserved: [(title: String, shortcut: BrowserShortcut)] {
        let editing: [(String, BrowserShortcut)] = [
            ("Cut", BrowserShortcut("x", .command)), ("Copy", BrowserShortcut("c", .command)),
            ("Paste", BrowserShortcut("v", .command)),
            ("Select All", BrowserShortcut("a", .command)),
            ("Undo", BrowserShortcut("z", .command)),
            ("Redo", BrowserShortcut("z", [.command, .shift])),
            ("Move Items Here", BrowserShortcut("v", [.command, .option])),
            ("Close Window", BrowserShortcut("w", .command)),
            ("Quit", BrowserShortcut("q", .command)),
            ("Minimize", BrowserShortcut("m", .command)), ("Hide", BrowserShortcut("h", .command)),
            ("Hide Others", BrowserShortcut("h", [.command, .option])),
        ]
        return editing
            + GoDestination.allCases.map {
                (
                    $0.title,
                    BrowserShortcut(String($0.key), BrowserShortcut.nativeModifiers($0.modifiers))
                )
            }
    }
}

enum ShortcutAssignmentError: LocalizedError {
    case invalid, usedBy(String)
    var errorDescription: String? {
        switch self {
        case .invalid: return "Include ⌘, ⌥ or ⌃"
        case .usedBy(let title): return "Used by \(title)"
        }
    }
}

struct BrowserShortcut: Equatable {
    let key: String
    let modifiers: Int
    init(key: String, modifiers: Int) { self.key = key; self.modifiers = modifiers }
    init(_ key: String, _ flags: NSEvent.ModifierFlags = []) {
        self.init(key: key, modifiers: Int(flags.rawValue))
    }
    var hasCommandModifiers: Bool {
        !NSEvent.ModifierFlags(rawValue: UInt(modifiers)).intersection([
            .command, .option, .control,
        ]).isEmpty
    }
    var isFunctionKey: Bool {
        key.unicodeScalars.count == 1 && (0xf704...0xf726).contains(key.unicodeScalars.first!.value)
    }
    static func eventModifiers(_ rawValue: Int) -> EventModifiers {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        var result: EventModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }
    static func nativeModifiers(_ value: EventModifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if value.contains(.control) { flags.insert(.control) }
        if value.contains(.option) { flags.insert(.option) }
        if value.contains(.shift) { flags.insert(.shift) }
        if value.contains(.command) { flags.insert(.command) }
        return flags
    }
    static func key(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36, 76: return "\r"
        case 51: return "\u{7f}"
        case 117: return "\u{f728}"
        case 123: return "\u{f702}"
        case 124: return "\u{f703}"
        case 125: return "\u{f701}"
        case 126: return "\u{f700}"
        default:
            let key = event.charactersIgnoringModifiers?.lowercased()
            if let scalar = key?.unicodeScalars.first, (0xf700...0xf8ff).contains(scalar.value) {
                return key
            }
            if event.modifierFlags.contains(.shift) {
                return event.characters(
                    byApplyingModifiers: event.modifierFlags.intersection(.command))?
                    .lowercased()
            }
            return key
        }
    }
    static func flags(for event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection([.command, .option, .control, .shift])
    }
    static func allowsUnmodified(_ key: String) -> Bool {
        key == "\r" || key == " " || BrowserShortcut(key).isFunctionKey
    }
    func matches(_ event: NSEvent) -> Bool {
        Self.key(for: event) == key && Int(Self.flags(for: event).rawValue) == modifiers
    }
    var title: String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        let name: String
        switch key {
        case "\r": name = "Enter"
        case " ": name = "Space"
        case "\u{7f}": name = "⌫"
        case "\u{f728}": name = "⌦"
        case "\u{f700}": name = "↑"
        case "\u{f701}": name = "↓"
        case "\u{f702}": name = "←"
        case "\u{f703}": name = "→"
        case "\t": name = "Tab"
        default:
            if isFunctionKey {
                name = "F\(key.unicodeScalars.first!.value - 0xf704 + 1)"
            } else {
                name = key.uppercased()
            }
        }
        return (flags.contains(.control) ? "⌃" : "")
            + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "")
            + (flags.contains(.command) ? "⌘" : "") + name
    }
}

private struct ConfigurableShortcut: ViewModifier {
    let action: BrowserShortcutAction
    @AppStorage private var key: String
    @AppStorage private var modifiers: Int
    init(action: BrowserShortcutAction) {
        self.action = action
        _key = AppStorage(wrappedValue: action.defaultKey, action.keyPreference)
        _modifiers = AppStorage(wrappedValue: action.defaultModifiers, action.modifiersPreference)
    }
    @ViewBuilder func body(content: Content) -> some View {
        if let shortcut = action.menuShortcut(for: BrowserShortcut(key: key, modifiers: modifiers))
        {
            content.keyboardShortcut(
                KeyEquivalent(Character(shortcut.key)),
                modifiers: BrowserShortcut.eventModifiers(shortcut.modifiers))
        } else {
            content
        }
    }
}

extension View {
    func configurableShortcut(_ action: BrowserShortcutAction) -> some View {
        modifier(ConfigurableShortcut(action: action))
    }
}

struct ShortcutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(ShortcutGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.rawValue).font(
                        .system(size: SettingsStyle.bodyFontSize, weight: .medium)
                    ).padding(
                        .bottom, 6)
                    ForEach(BrowserShortcutAction.allCases.filter { $0.group == group }) { action in
                        ShortcutSettingRow(action: action)
                        Divider()
                    }
                }
            }
            Button("Restore Defaults") {
                for action in BrowserShortcutAction.allCases {
                    UserDefaults.standard.removeObject(forKey: action.keyPreference)
                    UserDefaults.standard.removeObject(forKey: action.modifiersPreference)
                }
            }.buttonStyle(SettingsButtonStyle())
        }
    }
}

private struct ShortcutSettingRow: View {
    let action: BrowserShortcutAction
    @AppStorage private var key: String
    @AppStorage private var modifiers: Int
    init(action: BrowserShortcutAction) {
        self.action = action
        _key = AppStorage(wrappedValue: action.defaultKey, action.keyPreference)
        _modifiers = AppStorage(wrappedValue: action.defaultModifiers, action.modifiersPreference)
    }
    var body: some View {
        PreferenceRow(title: action.title) {
            ShortcutRecorder(
                action: action, shortcut: BrowserShortcut(key: key, modifiers: modifiers)
            )
            .frame(width: 232, height: 40)
            .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let action: BrowserShortcutAction
    let shortcut: BrowserShortcut
    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.isBordered = false
        button.font = .systemFont(ofSize: SettingsStyle.bodyFontSize, weight: .regular)
        button.contentTintColor = .labelColor
        button.focusRingType = .exterior
        button.target = button
        button.action = #selector(ShortcutRecorderButton.beginRecording)
        button.setAccessibilityLabel("\(action.title) shortcut")
        return button
    }
    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.shortcutTitle = shortcut.title
        if !button.recording { button.title = button.shortcutTitle }
        button.setAccessibilityValue(button.title)
        button.onRecord = { shortcut in
            do { try action.assign(shortcut); return nil } catch {
                return error.localizedDescription
            }
        }
    }
}

private final class ShortcutRecorderButton: NSButton {
    var shortcutTitle = ""
    private(set) var recording = false
    var onRecord: ((BrowserShortcut) -> String?)?
    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording() {
        window?.makeFirstResponder(self)
        recording = true
        title = "Press shortcut…"
        setAccessibilityValue(title)
    }
    override func resignFirstResponder() -> Bool {
        finishRecording()
        return super.resignFirstResponder()
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { record(event); return true }
        return super.performKeyEquivalent(with: event)
    }
    override func keyDown(with event: NSEvent) {
        if recording { record(event) } else { super.keyDown(with: event) }
    }
    private func record(_ event: NSEvent) {
        if event.keyCode == 53 { finishRecording(); return }
        let flags = BrowserShortcut.flags(for: event)
        guard let key = BrowserShortcut.key(for: event) else { return }
        let shortcut = BrowserShortcut(key: key, modifiers: Int(flags.rawValue))
        if let error = onRecord?(shortcut) {
            title = error
            setAccessibilityValue(title)
            return
        }
        shortcutTitle = shortcut.title
        finishRecording()
    }
    private func finishRecording() {
        recording = false
        title = shortcutTitle
        setAccessibilityValue(title)
    }
}
