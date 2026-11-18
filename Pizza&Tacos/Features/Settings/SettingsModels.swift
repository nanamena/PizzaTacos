import SwiftUI

// Esta enumeración define las cinco paletas seleccionables y sus muestras de color.
enum AppPalette: String, CaseIterable, Identifiable {
    case terracotta
    case sage
    case ocean
    case rose
    case plum

    var id: String { rawValue }

    var name: String {
        switch self {
        case .terracotta: "Terracotta"
        case .sage: "Sage"
        case .ocean: "Ocean"
        case .rose: "Rose"
        case .plum: "Plum"
        }
    }

    var swatches: [UInt32] {
        [colors.background, colors.surface, colors.primary, colors.secondary, colors.accent]
    }

    var colors: PaletteColors {
        switch self {
        case .terracotta:
            PaletteColors(background: 0xFFF8F0, surface: 0xFFFFFF, primary: 0xC65F32, secondary: 0xA94725, accent: 0xF4D5C2, text: 0x38251F,
                          darkBackground: 0x211711, darkSurface: 0x32231D, darkPrimary: 0xD87950, darkSecondary: 0xB85C38, darkAccent: 0x543629, darkText: 0xFFF8F0)
        case .sage:
            PaletteColors(background: 0xF5F8F0, surface: 0xFFFFFF, primary: 0x5D7860, secondary: 0x405844, accent: 0xD8E5D2, text: 0x263329,
                          darkBackground: 0x151D17, darkSurface: 0x202C23, darkPrimary: 0x8FB894, darkSecondary: 0x7AA67F, darkAccent: 0x344B39, darkText: 0xF5F8F0)
        case .ocean:
            PaletteColors(background: 0xF1F7F8, surface: 0xFFFFFF, primary: 0x36788A, secondary: 0x245868, accent: 0xCBE4E9, text: 0x20343A,
                          darkBackground: 0x142024, darkSurface: 0x1E3035, darkPrimary: 0x72B3C2, darkSecondary: 0x5598A9, darkAccent: 0x2B4850, darkText: 0xF1F7F8)
        case .rose:
            PaletteColors(background: 0xFFF5F4, surface: 0xFFFFFF, primary: 0xB95B63, secondary: 0x8F3F49, accent: 0xF1D2D2, text: 0x382326,
                          darkBackground: 0x211619, darkSurface: 0x332126, darkPrimary: 0xD97D83, darkSecondary: 0xB95B63, darkAccent: 0x512E34, darkText: 0xFFF5F4)
        case .plum:
            PaletteColors(background: 0xF8F4F9, surface: 0xFFFFFF, primary: 0x78628B, secondary: 0x59446C, accent: 0xE2D7EA, text: 0x302637,
                          darkBackground: 0x1D1722, darkSurface: 0x2D2434, darkPrimary: 0xAA91BD, darkSecondary: 0x8E76A2, darkAccent: 0x453650, darkText: 0xF8F4F9)
        }
    }
}

// Este modelo guarda los tonos de una paleta para los modos claro y oscuro.
struct PaletteColors {
    let background: UInt32
    let surface: UInt32
    let primary: UInt32
    let secondary: UInt32
    let accent: UInt32
    let text: UInt32
    let darkBackground: UInt32
    let darkSurface: UInt32
    let darkPrimary: UInt32
    let darkSecondary: UInt32
    let darkAccent: UInt32
    let darkText: UInt32

    var secondaryText: UInt32 { text.mixed(with: background, fraction: 0.70) }
    var border: UInt32 { text.mixed(with: background, fraction: 0.10) }
    var darkSecondaryText: UInt32 { darkText.mixed(with: darkBackground, fraction: 0.72) }
    var darkBorder: UInt32 { darkText.mixed(with: darkBackground, fraction: 0.14) }
}

private extension UInt32 {
    func mixed(with other: UInt32, fraction: Double) -> UInt32 {
        let red = Double((self >> 16) & 0xFF) * fraction + Double((other >> 16) & 0xFF) * (1 - fraction)
        let green = Double((self >> 8) & 0xFF) * fraction + Double((other >> 8) & 0xFF) * (1 - fraction)
        let blue = Double(self & 0xFF) * fraction + Double(other & 0xFF) * (1 - fraction)
        return (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue)
    }
}
import Foundation
import Combine

// Este modelo conserva los datos de perfil editables dentro del dispositivo.
struct UserProfile: Codable {
    var fullName: String
    var age: String
    var weight: String
    var height: String
    var fitnessGoal: String
    var trainingLevel: String

    static let placeholder = UserProfile(fullName: "Linda", age: "", weight: "", height: "", fitnessGoal: "General fitness", trainingLevel: "Beginner")
}

// Este almacén publica y guarda el perfil local para las pantallas de Settings.
@MainActor
final class UserProfileStore: ObservableObject {
    private let storageKey = "modifit.userProfile"

    @Published private(set) var profile: UserProfile

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = savedProfile
        } else {
            profile = .placeholder
        }
    }

    // Esta función valida y persiste el perfil nuevo en UserDefaults.
    func save(_ updatedProfile: UserProfile) {
        profile = updatedProfile
        if let data = try? JSONEncoder().encode(updatedProfile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
