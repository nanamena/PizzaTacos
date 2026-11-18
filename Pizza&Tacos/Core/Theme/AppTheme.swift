import SwiftUI
import UIKit

// Esta estructura resuelve colores de la paleta activa y adapta sus superficies al modo oscuro.
enum AppColors {
    static var background: Color { dynamic(.background) }
    static var surface: Color { dynamic(.surface) }
    static var primary: Color { dynamic(.primary) }
    static var secondary: Color { dynamic(.secondary) }
    static var accent: Color { dynamic(.accent) }
    static var text: Color { dynamic(.text) }
    static var secondaryText: Color { dynamic(.secondaryText) }
    static var border: Color { dynamic(.border) }

    // Esta función crea un color que vuelve a consultar la paleta cuando cambia el tema.
    private static func dynamic(_ role: PaletteRole) -> Color {
        Color(uiColor: UIColor { traits in
            let savedID = UserDefaults.standard.string(forKey: AppThemeStore.paletteKey) ?? AppPalette.terracotta.rawValue
            let palette = AppPalette(rawValue: savedID) ?? .terracotta
            let darkMode = traits.userInterfaceStyle == .dark
            let hex = palette.colors.value(for: role, darkMode: darkMode)
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
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
import SwiftUI
import Combine

// Este almacén conserva el modo de apariencia y la paleta elegida por la persona.
@MainActor
final class AppThemeStore: ObservableObject {
    static let appearanceKey = "modifit.appearance"
    static let paletteKey = "modifit.palette"

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    @Published var palette: AppPalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: Self.paletteKey) }
    }

    init() {
        appearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "system") ?? .system
        palette = AppPalette(rawValue: UserDefaults.standard.string(forKey: Self.paletteKey) ?? "terracotta") ?? .terracotta
    }

    var preferredColorScheme: ColorScheme? { appearance.colorScheme }
    var viewIdentity: String { "\(appearance.rawValue)-\(palette.rawValue)" }
}

// Esta enumeración convierte la preferencia guardada al esquema que entiende SwiftUI.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
