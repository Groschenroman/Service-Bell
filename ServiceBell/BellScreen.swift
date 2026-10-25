import SwiftUI

struct BellScreen: View {
    @State private var player = BellPlayer()
    @State private var isPressed = false
    @State private var rings = 0

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.20, green: 0.22, blue: 0.26), Color(red: 0.04, green: 0.05, blue: 0.08)],
                center: .center, startRadius: 0, endRadius: 600
            )
            .ignoresSafeArea()

            BellView(isPressed: isPressed)
                .padding(32)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: ring)
        .sensoryFeedback(.impact(weight: .medium), trigger: rings)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityElement()
        .accessibilityLabel("Service bell")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { ring() }
    }

    private func ring() {
        player.ring()
        rings += 1
        withAnimation(.easeOut(duration: 0.06)) { isPressed = true }
        withAnimation(.spring(duration: 0.3, bounce: 0.5).delay(0.08)) { isPressed = false }
    }
}

/// A desk service bell seen from straight above: black base, brass dome, plunger in the middle.
struct BellView: View {
    var isPressed: Bool

    private let brassLight = Color(red: 1.00, green: 0.95, blue: 0.62)
    private let brass = Color(red: 0.93, green: 0.76, blue: 0.25)
    private let brassDark = Color(red: 0.55, green: 0.38, blue: 0.08)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                base(size)
                dome(size * 0.80)
                    .scaleEffect(isPressed ? 0.985 : 1)
                plunger(size * 0.13)
                    .scaleEffect(isPressed ? 0.88 : 1)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func base(_ d: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.03)],
                                 center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: d * 0.6))
            .overlay(
                // Glossy lacquer reflection along the upper left edge
                Circle().strokeBorder(
                    AngularGradient(colors: [.white.opacity(0.0), .white.opacity(0.35), .white.opacity(0.0),
                                             .white.opacity(0.08), .white.opacity(0.0)],
                                    center: .center, angle: .degrees(150)),
                    lineWidth: d * 0.025)
                .padding(d * 0.02)
            )
            .frame(width: d, height: d)
            .shadow(color: .black.opacity(0.6), radius: d * 0.04, y: d * 0.025)
    }

    private func dome(_ d: CGFloat) -> some View {
        ZStack {
            // Body: lit from the top left, darkening toward the rim as the dome curves away
            Circle().fill(RadialGradient(
                stops: [
                    .init(color: brassLight, location: 0.0),
                    .init(color: brass, location: 0.35),
                    .init(color: Color(red: 0.80, green: 0.58, blue: 0.16), location: 0.72),
                    .init(color: brassDark, location: 1.0),
                ],
                center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: d * 0.72))

            // Warm reflected light along the lower right rim
            Circle().fill(RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.78),
                    .init(color: Color(red: 1, green: 0.88, blue: 0.55).opacity(0.45), location: 0.92),
                    .init(color: .clear, location: 1.0),
                ],
                center: UnitPoint(x: 0.42, y: 0.38), startRadius: 0, endRadius: d * 0.62))

            // Window-like reflection, typical for polished brass
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.9), .white.opacity(0.0)],
                                     center: .center, startRadius: 0, endRadius: d * 0.13))
                .frame(width: d * 0.30, height: d * 0.17)
                .rotationEffect(.degrees(-35))
                .offset(x: -d * 0.17, y: -d * 0.20)

            // Faint secondary reflection opposite the main one
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.35), .white.opacity(0.0)],
                                     center: .center, startRadius: 0, endRadius: d * 0.08))
                .frame(width: d * 0.16, height: d * 0.08)
                .rotationEffect(.degrees(-35))
                .offset(x: d * 0.24, y: d * 0.26)
        }
        .clipShape(Circle())
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.5), radius: d * 0.02, y: d * 0.01)
    }

    private func plunger(_ d: CGFloat) -> some View {
        ZStack {
            // Shadow the plunger casts onto the dome
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: d * 1.15, height: d * 1.15)
                .blur(radius: d * 0.12)
                .offset(x: d * 0.12, y: d * 0.16)

            Circle()
                .fill(RadialGradient(colors: [brassLight, brass, brassDark],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.6))
                .overlay(Circle().strokeBorder(brassDark.opacity(0.8), lineWidth: d * 0.04))
                .frame(width: d, height: d)

            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: d * 0.22, height: d * 0.22)
                .blur(radius: d * 0.04)
                .offset(x: -d * 0.18, y: -d * 0.2)
        }
    }
}

#Preview {
    BellScreen()
}
