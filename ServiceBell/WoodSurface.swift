import SwiftUI

/// Polished wood with vertical grain, drawn procedurally so it stays sharp on every screen.
struct WoodSurface: View {
    struct Style {
        var base: Color
        var light: Color
        var dark: Color
        var seed: UInt64
        var vignette: Bool
        /// Strength of the light texture details (groove edges, pore rims, fibres, sheen); 1 = full.
        var relief: Double = 1

        /// The dark walnut desk.
        static let walnut = Style(base: Color(red: 0.17, green: 0.10, blue: 0.06),
                                  light: Color(red: 0.36, green: 0.22, blue: 0.13),
                                  dark: Color(red: 0.07, green: 0.04, blue: 0.02),
                                  seed: 7, vignette: true)

        /// Wood painted black for the bell's base; only the grain's relief shows through.
        static let paintedBlack = Style(base: Color(white: 0.018),
                                        light: Color(white: 0.09),
                                        dark: Color(white: 0.0),
                                        seed: 23, vignette: false, relief: 0.45)
    }

    var style: Style

    var body: some View {
        let base = style.base, light = style.light, dark = style.dark, relief = style.relief
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededRandom(seed: style.seed)
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

            // Fine grain lines; dark ones are grooves, catching light on their upper left edge
            for _ in 0..<110 {
                let line = grainLine(in: size, rng: &rng, step: 6)
                let isGroove = rng.next() < 0.65
                let width = rng.next(in: 0.6...3)
                if isGroove {
                    context.stroke(line.offsetBy(dx: -width * 0.6, dy: 0),
                                   with: .color(.white.opacity(rng.next(in: 0.04...0.09) * relief)), lineWidth: 0.6)
                }
                context.stroke(line, with: .color((isGroove ? dark : light).opacity(rng.next(in: 0.12...0.40))),
                               lineWidth: width)
            }

            // Open pores: tiny dents running with the grain, lit on one rim
            for _ in 0..<Int(size.width * size.height / 260) {
                let p = CGPoint(x: rng.next(in: 0...size.width), y: rng.next(in: 0...size.height))
                let pore = CGRect(x: p.x, y: p.y, width: 0.8, height: rng.next(in: 2...6))
                context.fill(Path(ellipseIn: pore.offsetBy(dx: -0.5, dy: -0.5)), with: .color(.white.opacity(0.05 * relief)))
                context.fill(Path(ellipseIn: pore), with: .color(dark.opacity(rng.next(in: 0.15...0.45))))
            }

            // Fibre texture across the whole surface
            var fibres = context
            fibres.opacity = relief
            fibres.fill(Path(rect), with: .tiledImage(Self.fibreTile))

            // Lacquer sheen and vignette
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.07 * relief), .clear, .white.opacity(0.03 * relief), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            if style.vignette {
                context.fill(Path(rect), with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.55)]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: min(size.width, size.height) * 0.35,
                    endRadius: max(size.width, size.height) * 0.75))
            }
        }
    }

    /// Fine vertical wood fibres plus grit: short light and dark runs per pixel column, generated once.
    private static let fibreTile: Image = {
        let width = 256, height = 256
        var rng = SeededRandom(seed: 42)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for x in 0..<width {
            // Runs wrap around the bottom edge so the tile repeats without a visible seam
            let start = Int(rng.next(in: 0...CGFloat(height - 1)))
            var y = 0
            while y < height {
                let run = Int(rng.next(in: 6...60))
                let fibre = rng.next(in: -1...1)
                for offset in y..<min(y + run, height) {
                    let row = (start + offset) % height
                    let v = fibre * 0.6 + rng.next(in: -1...1) * 0.4
                    // Premultiplied RGBA: light fibres are faint white, dark ones faint black
                    let alpha = v >= 0 ? v * 0.10 : -v * 0.16
                    let i = (row * width + x) * 4
                    let channel = UInt8(v >= 0 ? alpha * 255 : 0)
                    pixels[i] = channel
                    pixels[i + 1] = channel
                    pixels[i + 2] = channel
                    pixels[i + 3] = UInt8(alpha * 255)
                }
                y += run
            }
        }

        let image = pixels.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return image.map { Image(decorative: $0, scale: 2) } ?? Image(systemName: "circle")
    }()

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
    WoodSurface(style: .walnut)
}
