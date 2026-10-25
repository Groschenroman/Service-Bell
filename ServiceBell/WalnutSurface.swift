import SwiftUI

/// A polished dark walnut desk surface, drawn procedurally so it stays sharp on every screen.
struct WalnutSurface: View {
    private let base = Color(red: 0.17, green: 0.10, blue: 0.06)
    private let light = Color(red: 0.36, green: 0.22, blue: 0.13)
    private let dark = Color(red: 0.07, green: 0.04, blue: 0.02)

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededRandom(seed: 7)
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(base))

            // Broad, soft colour bands give the wood its figure
            for _ in 0..<14 {
                let line = grainLine(in: size, rng: &rng, step: 12)
                let tone = rng.next() < 0.5 ? light : dark
                context.stroke(line, with: .color(tone.opacity(rng.next(in: 0.10...0.25))),
                               lineWidth: rng.next(in: 18...60))
            }

            // Medium streaks
            for _ in 0..<30 {
                let line = grainLine(in: size, rng: &rng, step: 8)
                let tone = rng.next() < 0.5 ? light : dark
                context.stroke(line, with: .color(tone.opacity(rng.next(in: 0.10...0.25))),
                               lineWidth: rng.next(in: 4...12))
            }

            // Fine grain lines
            for _ in 0..<110 {
                let line = grainLine(in: size, rng: &rng, step: 6)
                let tone = rng.next() < 0.65 ? dark : light
                context.stroke(line, with: .color(tone.opacity(rng.next(in: 0.12...0.40))),
                               lineWidth: rng.next(in: 0.6...3))
            }

            // Open pores: tiny dark streaks running with the grain
            for _ in 0..<Int(size.width * size.height / 260) {
                let p = CGPoint(x: rng.next(in: 0...size.width), y: rng.next(in: 0...size.height))
                let pore = Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 0.8, height: rng.next(in: 2...6)))
                context.fill(pore, with: .color(dark.opacity(rng.next(in: 0.15...0.45))))
            }

            // Lacquer sheen and vignette
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.07), .clear, .white.opacity(0.03), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.55)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: min(size.width, size.height) * 0.35,
                endRadius: max(size.width, size.height) * 0.75))
        }
        .ignoresSafeArea()
    }

    /// A gently wavering vertical line, like a growth ring cut lengthwise.
    private func grainLine(in size: CGSize, rng: inout SeededRandom, step: CGFloat) -> Path {
        let x0 = rng.next(in: -40...(size.width + 40))
        let a1 = rng.next(in: 4...24), f1 = rng.next(in: 0.002...0.008), p1 = rng.next(in: 0...(2 * .pi))
        let a2 = rng.next(in: 0.5...3), f2 = rng.next(in: 0.02...0.05), p2 = rng.next(in: 0...(2 * .pi))
        let drift = rng.next(in: -0.04...0.04)

        var path = Path()
        var y: CGFloat = -step
        while y <= size.height + step {
            let x = x0 + drift * y + a1 * sin(y * f1 + p1) + a2 * sin(y * f2 + p2)
            y == -step ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            y += step
        }
        return path
    }
}

/// Deterministic random numbers so the wood looks the same on every launch.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> CGFloat {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return CGFloat(z >> 11) / CGFloat(1 << 53)
    }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }
}

#Preview {
    WalnutSurface()
}
