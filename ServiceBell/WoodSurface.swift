import SwiftUI

/// Polished wood, drawn procedurally so it stays sharp on every screen.
struct WoodSurface: View {
    /// How the growth rings meet the surface.
    enum Grain {
        /// A board cut lengthwise: long, gently wavering vertical lines.
        case straight
        /// A disc cut across the trunk: closed, slightly lobed rings around `center`.
        case rings(center: UnitPoint)
    }

    struct Style {
        var base: Color
        var light: Color
        var dark: Color
        var seed: UInt64
        /// How much the edges darken; 0 = not at all.
        var vignette: Double = 0
        /// Strength of the light texture details (groove edges, pore rims, fibres, sheen); 1 = full.
        var relief: Double = 1
        var grain: Grain = .straight
        /// Number of fine grain lines; more makes the grain denser.
        var fineLines = 110
        /// Strength of the varnish's glossy reflections; 0 = none.
        var gloss: Double = 0

        /// A dark, warm walnut bar counter with dense, straight grain under a shiny coat of varnish.
        static let walnut = Style(base: Color(red: 0.21, green: 0.11, blue: 0.05),
                                  light: Color(red: 0.38, green: 0.21, blue: 0.10),
                                  dark: Color(red: 0.08, green: 0.04, blue: 0.015),
                                  seed: 7, vignette: 0.5, relief: 0.6, fineLines: 320, gloss: 1)

        /// Wood painted black for the bell's base; only the grain's relief shows through.
        /// The rings sit a little off-centre, as in a disc that wasn't cut from the exact middle of the log.
        static let paintedBlack = Style(base: Color(white: 0.018),
                                        light: Color(white: 0.09),
                                        dark: Color(white: 0.0),
                                        seed: 23, relief: 0.45,
                                        grain: .rings(center: UnitPoint(x: 0.43, y: 0.56)))
    }

    var style: Style

    var body: some View {
        let base = style.base, light = style.light, dark = style.dark, relief = style.relief
        Canvas(rendersAsynchronously: true) { context, size in
            var rng = SeededRandom(seed: style.seed)
            let rect = CGRect(origin: .zero, size: size)
            let lobes = Self.lobes(seed: style.seed)
            let grainLine = { (rng: inout SeededRandom, step: CGFloat) -> Path in
                switch style.grain {
                case .straight:
                    straightLine(in: size, flow: lobes, rng: &rng, step: step)
                case .rings(let center):
                    ringLine(around: CGPoint(x: center.x * size.width, y: center.y * size.height),
                             in: size, lobes: lobes, rng: &rng, step: step)
                }
            }
            context.fill(Path(rect), with: .color(base))

            // Broad, soft colour bands give the wood its figure
            for _ in 0..<14 {
                let line = grainLine(&rng, 12)
                let tone = rng.next() < 0.5 ? light : dark
                context.stroke(line, with: .color(tone.opacity(rng.next(in: 0.10...0.25))),
                               lineWidth: rng.next(in: 18...60))
            }

            // Medium streaks
            for _ in 0..<30 {
                let line = grainLine(&rng, 8)
                let tone = rng.next() < 0.5 ? light : dark
                context.stroke(line, with: .color(tone.opacity(rng.next(in: 0.10...0.25))),
                               lineWidth: rng.next(in: 4...12))
            }

            // Fine grain lines; dark ones are grooves, catching light on their upper left edge
            for _ in 0..<style.fineLines {
                let line = grainLine(&rng, 6)
                let isGroove = rng.next() < 0.65
                let width = rng.next(in: 0.6...3)
                if isGroove {
                    context.stroke(line.offsetBy(dx: -width * 0.6, dy: 0),
                                   with: .color(.white.opacity(rng.next(in: 0.04...0.09) * relief)), lineWidth: 0.6)
                }
                context.stroke(line, with: .color((isGroove ? dark : light).opacity(rng.next(in: 0.12...0.40))),
                               lineWidth: width)
            }

            // Open pores: thin dents running with the grain, lit on one rim; cut across, they show as dots
            let isEndGrain = if case .rings = style.grain { true } else { false }
            for _ in 0..<Int(size.width * size.height / 260) {
                let p = CGPoint(x: rng.next(in: 0...size.width), y: rng.next(in: 0...size.height))
                let pore = CGRect(x: p.x, y: p.y, width: isEndGrain ? rng.next(in: 0.8...1.6) : 0.8,
                                  height: isEndGrain ? rng.next(in: 0.8...1.6) : rng.next(in: 3...12))
                context.fill(Path(ellipseIn: pore.offsetBy(dx: -0.5, dy: -0.5)), with: .color(.white.opacity(0.05 * relief)))
                context.fill(Path(ellipseIn: pore), with: .color(dark.opacity(rng.next(in: 0.15...0.45))))
            }

            // Fibre texture across the whole surface; its straight fibres would cross rings, so end grain goes without
            if !isEndGrain {
                var fibres = context
                fibres.opacity = relief
                fibres.fill(Path(rect), with: .tiledImage(Self.fibreTile))
            }

            // Lacquer sheen and vignette
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [.white.opacity(0.07 * relief), .clear, .white.opacity(0.03 * relief), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            if style.vignette > 0 {
                context.fill(Path(rect), with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(style.vignette)]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: min(size.width, size.height) * 0.35,
                    endRadius: max(size.width, size.height) * 0.75))
            }

            if style.gloss > 0 {
                drawVarnish(in: &context, size: size, gloss: style.gloss)
            }
        }
    }

    /// Lit like a bar counter: a warm pendant lamp hangs above the upper left, pooling light around it,
    /// and the varnish mirrors it as a round, soft glow. A second lamp further along the bar shows only
    /// faintly at the top right edge.
    private func drawVarnish(in context: inout GraphicsContext, size: CGSize, gloss: Double) {
        let w = size.width, h = size.height, unit = min(w, h)
        let rect = CGRect(origin: .zero, size: size)
        let warm = Color(red: 1.0, green: 0.76, blue: 0.48)
        let lamp = CGPoint(x: w * 0.27, y: h * 0.15)

        context.drawLayer { layer in
            layer.blendMode = .screen

            // Pool of warm light, fading into the dark further away
            layer.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [warm.opacity(0.30 * gloss), warm.opacity(0.10 * gloss), .clear]),
                center: lamp, startRadius: 0, endRadius: max(w, h) * 0.6))

            // The lamps' reflections: round soft glows, the near one with a brighter core;
            // diameters are fractions of the width so they stay round on every screen
            let reflections: [(center: CGPoint, diameter: CGFloat, blur: CGFloat, alpha: Double)] = [
                (lamp, w * 0.34, 0.07, 0.15),
                (lamp, w * 0.13, 0.035, 0.24),
                (CGPoint(x: w * 0.92, y: -h * 0.01), w * 0.14, 0.04, 0.12),
            ]
            for reflection in reflections {
                layer.drawLayer { glow in
                    glow.addFilter(.blur(radius: unit * reflection.blur))
                    glow.fill(Path(ellipseIn: CGRect(x: reflection.center.x - reflection.diameter / 2,
                                                     y: reflection.center.y - reflection.diameter / 2,
                                                     width: reflection.diameter, height: reflection.diameter)),
                              with: .color(warm.opacity(reflection.alpha * gloss)))
                }
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

    /// Shared bumps that every grain line follows, so neighbouring lines stay roughly parallel like real growth rings.
    private static func lobes(seed: UInt64) -> [(harmonic: CGFloat, amount: CGFloat, phase: CGFloat)] {
        var rng = SeededRandom(seed: seed &+ 1)
        return (2...4).map { (CGFloat($0), rng.next(in: 0.01...0.04), rng.next(in: 0...(2 * .pi))) }
    }

    /// A nearly straight vertical line, like a growth ring cut lengthwise. All lines follow the same gentle
    /// `flow`, so they run side by side like real grain, each with only a small sway of its own.
    private func straightLine(in size: CGSize, flow: [(harmonic: CGFloat, amount: CGFloat, phase: CGFloat)],
                              rng: inout SeededRandom, step: CGFloat) -> Path {
        let x0 = rng.next(in: -40...(size.width + 40))
        let a1 = rng.next(in: 1...5), f1 = rng.next(in: 0.002...0.006), p1 = rng.next(in: 0...(2 * .pi))
        let a2 = rng.next(in: 0.2...1), f2 = rng.next(in: 0.02...0.05), p2 = rng.next(in: 0...(2 * .pi))
        let drift = rng.next(in: -0.006...0.006)
        let shared = { (y: CGFloat) in
            flow.reduce(0) { $0 + $1.amount * 150 * sin($1.harmonic * 0.5 * .pi * y / size.height + $1.phase) }
        }

        var path = Path()
        var y: CGFloat = -step
        while y <= size.height + step {
            let x = x0 + shared(y) + drift * y + a1 * sin(y * f1 + p1) + a2 * sin(y * f2 + p2)
            y == -step ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            y += step
        }
        return path
    }

    /// A closed growth ring around `center`, lobed like its neighbours and with a slight wobble of its own.
    private func ringLine(around center: CGPoint, in size: CGSize,
                          lobes: [(harmonic: CGFloat, amount: CGFloat, phase: CGFloat)],
                          rng: inout SeededRandom, step: CGFloat) -> Path {
        let maxRadius = hypot(max(center.x, size.width - center.x), max(center.y, size.height - center.y))
        let r = rng.next(in: 2...maxRadius)
        let wobble = rng.next(in: 0.3...2), frequency = rng.next(in: 3...9).rounded(), phase = rng.next(in: 0...(2 * .pi))
        let count = max(16, Int(2 * .pi * r / step))

        var path = Path()
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            var radius = r + wobble * sin(frequency * angle + phase)
            for lobe in lobes { radius += r * lobe.amount * sin(lobe.harmonic * angle + lobe.phase) }
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
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
