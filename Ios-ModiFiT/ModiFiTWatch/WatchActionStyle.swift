import SwiftUI

struct WatchActionStyle: ButtonStyle {
    enum Kind { case primary, secondary, start, destructive }

    var kind: Kind = .primary
    @Environment(\.appColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .start: Color(hex: colors.palette.colors.darkBackground)
        case .secondary: colors.text
        case .destructive: Color(red: 1, green: 0.39, blue: 0.40)
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary: AnyShapeStyle(colors.primary)
        case .start: AnyShapeStyle(LinearGradient(colors: [colors.primary, colors.primary.opacity(0.88)], startPoint: .top, endPoint: .bottom))
        case .secondary, .destructive: AnyShapeStyle(colors.surface)
        }
    }
}
