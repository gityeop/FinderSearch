import SwiftUI

enum SettingsStyle {
    static let bodyFontSize: CGFloat = 16
    static let bodyFont = Font.system(size: bodyFontSize, weight: .regular)
    static let sectionFont = Font.system(size: 18, weight: .semibold)
    static let titleFont = Font.system(size: 20, weight: .semibold)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let border = Color.primary.opacity(0.10)
    static let hover = Color.primary.opacity(0.045)
    static let selection = Color.primary.opacity(0.075)
    static let blue = Color(red: 0.16, green: 0.49, blue: 0.97)
}

struct SettingsChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct SettingsPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [SettingsChoice<Value>]
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
            HStack(spacing: 12) {
                ForEach(choices.filter { $0.value == selection }) { choice in
                    Text(choice.title).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SettingsButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(choices.filter { $0.value == selection }.map(\.title).joined())
        .popover(isPresented: $presented, arrowEdge: .top) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(choices) { choice in
                            Button {
                                selection = choice.value
                                presented = false
                            } label: {
                                HStack(spacing: 12) {
                                    Text(choice.title).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 0)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .opacity(choice.value == selection ? 1 : 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .padding(.horizontal, 10)
                            }
                            .buttonStyle(SettingsOptionStyle())
                            .accessibilityAddTraits(choice.value == selection ? .isSelected : [])
                        }
                    }.padding(6)
                }
                .frame(height: min(CGFloat(choices.count * 42 + 12), 320))
                if let actionTitle, let action {
                    Divider().padding(.horizontal, 6)
                    Button {
                        presented = false
                        action()
                    } label: {
                        Text(actionTitle).frame(
                            maxWidth: .infinity, minHeight: 40, alignment: .leading
                        )
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(SettingsOptionStyle()).padding(6)
                }
            }
            .font(SettingsStyle.bodyFont)
            .frame(width: 296)
            .background(SettingsStyle.surface)
        }
    }
}

struct SettingsButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SettingsStyle.bodyFont)
            .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.35))
            .padding(.horizontal, 12).frame(minHeight: 40)
            .background(
                configuration.isPressed || hovering ? SettingsStyle.hover : SettingsStyle.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
    }
}

struct SettingsOptionStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                hovering || configuration.isPressed ? SettingsStyle.selection : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}

struct SettingsIconButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SettingsStyle.bodyFont)
            .foregroundStyle(.secondary)
            .frame(width: 34, height: 34)
            .background(
                hovering || configuration.isPressed ? SettingsStyle.hover : .clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .onHover { hovering = $0 }
    }
}

struct SettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.textFieldStyle(.plain)
            .font(SettingsStyle.bodyFont)
            .padding(.horizontal, 12).frame(height: 40)
            .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.border) }
    }
}

struct SettingsSwitchStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule().fill(configuration.isOn ? SettingsStyle.blue : Color.primary.opacity(0.18))
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                }
                .frame(width: 38, height: 22)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.14), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        }
    }
}
