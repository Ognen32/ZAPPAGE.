import SwiftUI

// Form field with leading icon, focus-ring, and optional trailing view.
// Matches the Field component in the design reference (auth.jsx).
struct ZapTextField<Trailing: View>: View {
    let icon: String              // SF Symbol name
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var tone: ZapTheme.Tone
    var accent: Color = ZapTheme.accent
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(focused ? tone.text : tone.textDim)
                .frame(width: 18, height: 18)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(tone.text)
            .tint(accent)
            .focused($focused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(focused ? tone.fieldFocus : tone.field)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focused ? accent.opacity(0.5) : tone.chipBorder, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.12), value: focused)
    }
}

// Convenience init without a trailing view
extension ZapTextField where Trailing == EmptyView {
    init(icon: String, placeholder: String, text: Binding<String>,
         isSecure: Bool = false, tone: ZapTheme.Tone, accent: Color = ZapTheme.accent) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.tone = tone
        self.accent = accent
        self.trailing = { EmptyView() }
    }
}
