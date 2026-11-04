import AppKit
import SwiftUI

enum CopyPathShortcut {
    static let keyPreference = "copyPathShortcutKey"
    static let modifiersPreference = "copyPathShortcutModifiers"
    static let defaultKey = "c"
    static let defaultModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)

    static func eventModifiers(_ rawValue: Int) -> EventModifiers {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        var result: EventModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }

    static func title(key: String, modifiers: Int) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        return (flags.contains(.control) ? "⌃" : "")
            + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "")
            + (flags.contains(.command) ? "⌘" : "") + key.uppercased()
    }
}

struct ShortcutSettingsView: View {
    @AppStorage(CopyPathShortcut.keyPreference) private var key = CopyPathShortcut.defaultKey
    @AppStorage(CopyPathShortcut.modifiersPreference) private var modifiers = CopyPathShortcut.defaultModifiers

    var body: some View {
        Form {
            LabeledContent("Copy Path") {
                ShortcutRecorder(key: $key, modifiers: $modifiers).frame(width: 190, height: 28)
            }
            Text("Click the shortcut, then press a new combination with Command, Option, or Control. Escape cancels.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Restore Default") {
                key = CopyPathShortcut.defaultKey
                modifiers = CopyPathShortcut.defaultModifiers
            }
            .disabled(key == CopyPathShortcut.defaultKey && modifiers == CopyPathShortcut.defaultModifiers)
        }
        .padding(24).frame(width: 440).navigationTitle("Keyboard Shortcuts")
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    @Binding var key: String
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(ShortcutRecorderButton.beginRecording)
        button.setAccessibilityLabel("Copy Path shortcut")
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.shortcutTitle = CopyPathShortcut.title(key: key, modifiers: modifiers)
        if !button.recording { button.title = button.shortcutTitle }
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
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty,
            let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1
        else {
            title = "Include ⌘, ⌥ or ⌃"
            return
        }
        onRecord?(key, Int(flags.rawValue))
        shortcutTitle = CopyPathShortcut.title(key: key, modifiers: Int(flags.rawValue))
        finishRecording()
    }

    private func finishRecording() {
        recording = false
        title = shortcutTitle
    }
}
