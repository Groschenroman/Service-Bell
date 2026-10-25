import SwiftUI

struct BellScreen: View {
    @State private var player = BellPlayer()
    @State private var rings = 0

    var body: some View {
        ZStack {
            WoodSurface(style: .walnut)
                .ignoresSafeArea()

            KeyframeAnimator(initialValue: BellMotion(), trigger: rings) { motion in
                BellView(motion: motion)
                    .contentShape(Circle())
                    .onTapGesture(perform: ring)
            } keyframes: { _ in
                // Knob: snaps down, rests a moment, then the spring pushes it back with a slight overshoot
                KeyframeTrack(\.knobDepth) {
                    CubicKeyframe(1, duration: 0.05)
                    LinearKeyframe(1, duration: 0.04)
                    SpringKeyframe(0, duration: 0.32, spring: .init(duration: 0.32, bounce: 0.45))
                }
                // Dome: the struck brass vibrates briefly and fades out
                KeyframeTrack(\.domeVibration) {
                    LinearKeyframe(0, duration: 0.07)
                    CubicKeyframe(1, duration: 0.04)
                    CubicKeyframe(-0.7, duration: 0.06)
                    CubicKeyframe(0.45, duration: 0.06)
                    CubicKeyframe(-0.25, duration: 0.07)
                    CubicKeyframe(0.1, duration: 0.08)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
            .padding(32)
        }
        // Tapping the table muffles the bell; taps on the bell itself are handled above
        .contentShape(Rectangle())
        .onTapGesture { player.silence() }
        .sensoryFeedback(.impact(weight: .medium), trigger: rings)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityElement()
        .accessibilityLabel("Service bell")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { ring() }
        .accessibilityAction(named: "Stop ringing") { player.silence() }
        .overlay(alignment: .bottom) {
            Text(verbatim: "Service bell louder by Squidems - freesound.org/s/709925 - Creative Commons 0")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .allowsHitTesting(false) // taps on the note count as taps on the table
        }
    }

    private func ring() {
        player.ring()
        rings += 1
    }
}

struct BellMotion {
    /// 0 = knob at rest, 1 = pushed all the way down.
    var knobDepth: CGFloat = 0
    /// -1...1, the dome's ringing after being struck.
    var domeVibration: CGFloat = 0
}

/// A desk service bell seen from straight above: black base, brass dome, plunger in the middle.
struct BellView: View {
    var motion = BellMotion()

    private let brassLight = Color(red: 1.00, green: 0.95, blue: 0.62)
    private let brass = Color(red: 0.93, green: 0.76, blue: 0.25)
    private let brassDark = Color(red: 0.55, green: 0.38, blue: 0.08)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                base(size)
                dome(size * 0.80)
                    .scaleEffect(1 + motion.domeVibration * 0.004)
                plunger(size * 0.13, depth: motion.knobDepth)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// A turned wooden base painted black, its grain running across like the board it was cut from.
    private func base(_ d: CGFloat) -> some View {
        ZStack {
            WoodSurface(style: .paintedBlack)
                .rotationEffect(.degrees(90))

            // Rounded outer edge: lit from the top left, falling into shadow at the bottom right
            Circle().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: d * 0.035)
                .blur(radius: d * 0.006)

            // Lacquer reflection along the upper left edge
            Circle().strokeBorder(
                AngularGradient(colors: [.white.opacity(0.0), .white.opacity(0.3), .white.opacity(0.0),
                                         .white.opacity(0.06), .white.opacity(0.0)],
                                center: .center, angle: .degrees(150)),
                lineWidth: d * 0.018)
                .padding(d * 0.045)

            // Soft sheen across the polished top
            Circle().fill(RadialGradient(colors: [.white.opacity(0.07), .clear],
                                         center: UnitPoint(x: 0.3, y: 0.25), startRadius: 0, endRadius: d * 0.5))

            // Seat where the dome meets the wood
            Circle()
                .stroke(.black.opacity(0.6), lineWidth: d * 0.012)
                .frame(width: d * 0.81, height: d * 0.81)
                .blur(radius: d * 0.004)
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
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

    /// `depth` 0...1: as the knob sinks toward the dome it moves away from the viewer (smaller, a little darker)
    /// and its shadow tightens and slides in underneath it.
    private func plunger(_ d: CGFloat, depth: CGFloat) -> some View {
        let lift = 1 - depth * 0.75 // remaining gap between knob and dome
        return ZStack {
            // Shadow the plunger casts onto the dome
            Circle()
                .fill(.black.opacity(0.35 + depth * 0.2))
                .frame(width: d * (1.0 + 0.15 * lift), height: d * (1.0 + 0.15 * lift))
                .blur(radius: d * (0.04 + 0.08 * lift))
                .offset(x: d * 0.12 * lift, y: d * 0.16 * lift)

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [brassLight, brass, brassDark],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.6))
                    .overlay(Circle().strokeBorder(brassDark.opacity(0.8), lineWidth: d * 0.04))
                    .overlay(Circle().fill(.black.opacity(depth * 0.18)))
                    .frame(width: d, height: d)

                Circle()
                    .fill(.white.opacity(0.85 - depth * 0.3))
                    .frame(width: d * 0.22, height: d * 0.22)
                    .blur(radius: d * 0.04)
                    .offset(x: -d * 0.18, y: -d * 0.2)
            }
            .scaleEffect(1 - depth * 0.1)
        }
    }
}

#Preview {
    BellScreen()
}
