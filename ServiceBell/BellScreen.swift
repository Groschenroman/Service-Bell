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

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                castShadow(size)
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

    /// The lamp hangs above the upper left, so the bell's shadow falls toward the lower right: a tight, dark
    /// contact shadow where the base sits, and a longer, softer one from the taller dome.
    private func castShadow(_ d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.7))
                .frame(width: d * 0.85, height: d * 0.85)
                .blur(radius: d * 0.06)
                .offset(x: d * 0.16, y: d * 0.22)
            Circle()
                .fill(.black.opacity(0.8))
                .blur(radius: d * 0.035)
                .offset(x: d * 0.06, y: d * 0.085)
            Circle()
                .fill(.black.opacity(0.85))
                .blur(radius: d * 0.01)
                .offset(x: d * 0.012, y: d * 0.018)
        }
        .frame(width: d, height: d)
    }

    /// A turned wooden base painted black, its growth rings circling the middle.
    private func base(_ d: CGFloat) -> some View {
        ZStack {
            WoodSurface(style: .paintedBlack)

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
    }

    /// A simply rounded dome of polished brass, its surface faintly rippled by the lathe,
    /// mirroring the lamp, window, ceiling and counter.
    private func dome(_ d: CGFloat) -> some View {
        brass(d, shape: 0)
            .shadow(color: .black.opacity(0.5), radius: d * 0.02, x: d * 0.006, y: d * 0.01)
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

            // A flat brass button with a rounded edge; the back-bar light shows as a short, soft band at its lower right
            brass(d, shape: 1, darken: depth * 0.25)
                .overlay {
                    // Brightest in the middle of the band, fading out toward both ends and, through the blur, its sides
                    Circle()
                        .stroke(AngularGradient(colors: [.clear, .white.opacity(0.8 - depth * 0.35), .clear],
                                                center: .center, startAngle: .degrees(-10), endAngle: .degrees(100)),
                                lineWidth: d * 0.15)
                        .frame(width: d * 0.66, height: d * 0.66)
                        .blur(radius: d * 0.045)
                }
                .scaleEffect(1 - depth * 0.1)
        }
    }

    /// A round piece of polished brass rendered by the `brass` shader in Brass.metal; `shape` 0 is the dome, 1 the button.
    private func brass(_ d: CGFloat, shape: Float, darken: CGFloat = 0) -> some View {
        Circle()
            .fill(.white)
            .frame(width: d, height: d)
            .colorEffect(ShaderLibrary.brass(.float2(d, d), .float(shape), .float(darken)))
    }
}

#Preview {
    BellScreen()
}
