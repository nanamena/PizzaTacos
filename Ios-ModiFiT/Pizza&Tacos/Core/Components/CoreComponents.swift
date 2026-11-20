import SwiftUI

// Este modificador aplica superficies, borde y sombra consistentes a las tarjetas.
struct AppCard: ViewModifier {
    @Environment(\.appColors) private var appColors

    func body(content: Content) -> some View {
        content
            .background(appColors.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(appColors.border, lineWidth: 1))
            .shadow(color: appColors.text.opacity(0.055), radius: 13, x: 0, y: 5)
    }
}

extension View {
    func appCard() -> some View { modifier(AppCard()) }
}

// Este estilo ofrece una respuesta táctil breve al presionar tarjetas o botones.
struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
import SwiftUI

// Este componente conserva las proporciones de la mascota y añade un movimiento de reposo discreto.
struct MascotView: View {
    var body: some View {
        Image("ModiFiTMascot")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("ModiFiT fitness mascot")
    }
}

// Esta vista muestra una ilustración de la mascota con una animación flotante sutil.
struct FloatingMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                MascotView()
            } else {
                MascotView()
                    .phaseAnimator([false, true]) { mascot, isFloating in
                        mascot.offset(y: isFloating ? -2 : 2)
                    } animation: { _ in
                        .easeInOut(duration: 2.2)
                    }
            }
        }
    }
}
