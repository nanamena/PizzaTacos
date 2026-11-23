import Combine
import Foundation

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
