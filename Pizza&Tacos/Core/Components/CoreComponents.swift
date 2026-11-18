import SwiftUI

// Este modificador aplica superficies, borde y sombra consistentes a las tarjetas.
struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppColors.border, lineWidth: 1))
            .shadow(color: AppColors.text.opacity(0.055), radius: 13, x: 0, y: 5)
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

// Este componente presenta las tres pestañas con un indicador nativo y accesible.
struct BottomNavigationBar: View {
    @Binding var selection: AppTab
    var isInteractive = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol).font(.system(size: 23, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 14, weight: selection == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selection == tab ? AppColors.primary : AppColors.text)
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .background(selection == tab ? AppColors.accent.opacity(0.78) : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isInteractive)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(AppColors.surface, in: Capsule())
        .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
        .shadow(color: AppColors.text.opacity(0.07), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 22).padding(.top, 7).padding(.bottom, 5)
        .background(.ultraThinMaterial)
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
    var body: some View {
        MascotView()
            .phaseAnimator([false, true]) { mascot, isFloating in
                mascot.offset(y: isFloating ? -2 : 2)
            } animation: { _ in
                .easeInOut(duration: 2.2)
            }
    }
}
