import Combine
import SwiftUI

// Los colores dependen de la paleta seleccionada y de la apariencia de iOS.
struct AppColors: Equatable {
    let palette: AppPalette
    let colorScheme: ColorScheme

    var background: Color { color(.background) }
    var surface: Color { color(.surface) }
    var card: Color { surface }
    var primary: Color { color(.primary) }
    var secondary: Color { color(.secondary) }
    var accent: Color { color(.accent) }
    var text: Color { color(.text) }
    var secondaryText: Color { color(.secondaryText) }
    var border: Color { color(.border) }

    private func color(_ role: PaletteRole) -> Color {
        Color(hex: palette.colors.value(for: role, darkMode: colorScheme == .dark))
    }
}

extension EnvironmentValues {
    @Entry var appColors = AppColors(palette: .terracotta, colorScheme: .light)
}

struct AppTheme: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let palette: AppPalette

    func body(content: Content) -> some View {
        let colors = AppColors(palette: palette, colorScheme: colorScheme)
        content
            .tint(colors.primary)
            .environment(\.appColors, colors)
    }
}

// Estos roles evitan repetir la selección claro/oscuro para cada componente de color.
private enum PaletteRole {
    case background, surface, primary, secondary, accent, text, secondaryText, border
}

private extension PaletteColors {
    func value(for role: PaletteRole, darkMode: Bool) -> UInt32 {
        switch (role, darkMode) {
        case (.background, false): background
        case (.surface, false): surface
        case (.primary, false): primary
        case (.secondary, false): secondary
        case (.accent, false): accent
        case (.text, false): text
        case (.secondaryText, false): secondaryText
        case (.border, false): border
        case (.background, true): darkBackground
        case (.surface, true): darkSurface
        case (.primary, true): darkPrimary
        case (.secondary, true): darkSecondary
        case (.accent, true): darkAccent
        case (.text, true): darkText
        case (.secondaryText, true): darkSecondaryText
        case (.border, true): darkBorder
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
// Este almacén conserva la paleta elegida por la persona.
@MainActor
final class AppThemeStore: ObservableObject {
    private static let legacyAppearanceKey = "modifit.appearance"
    private static let paletteKey = "modifit.palette"

    @Published var palette: AppPalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: Self.paletteKey) }
    }

    init() {
        UserDefaults.standard.removeObject(forKey: Self.legacyAppearanceKey)
        let savedPalette = UserDefaults.standard.string(forKey: Self.paletteKey)
        palette = savedPalette.flatMap(AppPalette.init(rawValue:)) ?? .terracotta
    }
}
