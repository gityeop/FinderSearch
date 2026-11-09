import AppKit
import SwiftUI

enum BrowserShortcutAction: String, CaseIterable, Identifiable {
    case open, rename, copyPath
    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: return "Open Selected"
        case .rename: return "Rename"
        case .copyPath: return "Copy Path"
        }
    }
    var keyPreference: String { rawValue + "ShortcutKey" }
    var modifiersPreference: String { rawValue + "ShortcutModifiers" }
    var defaultKey: String {
        switch self {
        case .open: return "\r"
        case .rename: return "\u{f705}"
        case .copyPath: return "c"
        }
    }
    var defaultModifiers: Int {
        self == .copyPath ? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue) : 0
    }
    func shortcut(in defaults: UserDefaults = .standard) -> BrowserShortcut {
        BrowserShortcut(
            key: defaults.string(forKey: keyPreference) ?? defaultKey,
            modifiers: defaults.object(forKey: modifiersPreference) as? Int ?? defaultModifiers)
    }
    static func navigationAction(for event: NSEvent, in defaults: UserDefaults = .standard)
        -> BrowserShortcutAction?
    {
        [.open, .rename].first { $0.shortcut(in: defaults).matches(event) }
    }
}

struct BrowserShortcut {
    let key: String
    let modifiers: Int

    static func eventModifiers(_ rawValue: Int) -> EventModifiers {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        var result: EventModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }
    static func key(for event: NSEvent) -> String? {
        if event.keyCode == 36 || event.keyCode == 76 { return "\r" }
        return event.charactersIgnoringModifiers?.lowercased()
    }
    static func flags(for event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection([.command, .option, .control, .shift])
    }
    static func allowsUnmodified(_ key: String) -> Bool {
        key == "\r" || key.unicodeScalars.count == 1
            && (0xf704...0xf726).contains(key.unicodeScalars.first!.value)
    }
    func matches(_ event: NSEvent) -> Bool {
        Self.key(for: event) == key && Int(Self.flags(for: event).rawValue) == modifiers
    }
    var title: String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        let name: String
        if key == "\r" {
            name = "Enter"
        } else if let scalar = key.unicodeScalars.first, (0xf704...0xf726).contains(scalar.value) {
            name = "F\(scalar.value - 0xf704 + 1)"
        } else {
            name = key.uppercased()
        }
        return (flags.contains(.control) ? "⌃" : "")
            + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "")
            + (flags.contains(.command) ? "⌘" : "") + name
    }
}

struct ShortcutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(BrowserShortcutAction.allCases) { action in
                ShortcutSettingRow(action: action).padding(.vertical, 14)
                Divider()
            }
            Text("Click a shortcut, then press a new combination. Enter and function keys can be used on their own. Escape cancels.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 20)
            Button("Restore Defaults") {
                for action in BrowserShortcutAction.allCases {
                    UserDefaults.standard.removeObject(forKey: action.keyPreference)
                    UserDefaults.standard.removeObject(forKey: action.modifiersPreference)
                }
            }
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
        HStack(spacing: 16) {
            Text(action.title).font(.system(size: 13))
            Spacer()
            ShortcutRecorder(label: action.title, key: $key, modifiers: $modifiers)
                .frame(width: 155, height: 28)
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    @Binding var key: String
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(ShortcutRecorderButton.beginRecording)
        button.setAccessibilityLabel("\(label) shortcut")
        return button
    }
    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.shortcutTitle = BrowserShortcut(key: key, modifiers: modifiers).title
        if !button.recording { button.title = button.shortcutTitle }
        button.setAccessibilityValue(button.title)
        button.onRecord = { newKey, newModifiers in
            key = newKey
            modifiers = newModifiers
        }
    }
}

private final class ShortcutRecorderButton: NSButton {
    var shortcutTitle = ""
    private(set) var recording = false
    var onRecord: ((String, Int) -> Void)?
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
        guard let key = BrowserShortcut.key(for: event), key.count == 1,
            BrowserShortcut.allowsUnmodified(key)
                || !flags.intersection([.command, .option, .control]).isEmpty
        else {
            title = "Include ⌘, ⌥ or ⌃"
            setAccessibilityValue(title)
            return
        }
        onRecord?(key, Int(flags.rawValue))
        shortcutTitle = BrowserShortcut(key: key, modifiers: Int(flags.rawValue)).title
        finishRecording()
    }
    private func finishRecording() {
        recording = false
        title = shortcutTitle
        setAccessibilityValue(title)
    }
}
