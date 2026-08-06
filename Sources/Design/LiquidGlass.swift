import SwiftUI

// MARK: - Verre

/// Surface de verre : matériau flou, voile teinté, arête spéculaire, ombre portée.
///
/// Implémentation maison plutôt que l'API `glassEffect` d'iOS 26 : elle compile
/// à partir d'iOS 17 et reste identique quelle que soit la version du SDK.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = Theme.radiusCard
    var material: Material = .ultraThinMaterial
    var tinted: Bool = true
    var stroke: Double = 1
    var elevation: Double = 1

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(material)
                    if tinted { shape.fill(Theme.glassTint) }
                }
            }
            .overlay {
                shape.strokeBorder(Theme.specular, lineWidth: stroke)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.34 * elevation), radius: 18 * elevation, y: 9 * elevation)
            .shadow(color: Theme.emerald.opacity(0.05 * elevation), radius: 26 * elevation, y: 2)
    }
}

extension View {
    func glass(
        radius: CGFloat = Theme.radiusCard,
        material: Material = .ultraThinMaterial,
        tinted: Bool = true,
        stroke: Double = 1,
        elevation: Double = 1
    ) -> some View {
        modifier(GlassSurface(radius: radius, material: material,
                              tinted: tinted, stroke: stroke, elevation: elevation))
    }
}

// MARK: - Fond liquide

/// Halos colorés qui dérivent lentement derrière le contenu — la part « liquide »
/// du liquid glass : c'est leur mouvement que le verre réfracte.
///
/// Animé par `repeatForever` (piloté par le compositeur) plutôt que par un
/// `TimelineView` par image, pour ne pas réveiller le CPU 30 fois par seconde.
struct LiquidBackdrop: View {
    @State private var drift = false
    /// Réduit l'amplitude quand le fond passe derrière une feuille modale.
    var intensity: Double = 1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Theme.canvas.ignoresSafeArea()

                orb(Theme.emerald.opacity(0.34 * intensity), size: w * 1.05)
                    .offset(x: drift ? -w * 0.28 : w * 0.20,
                            y: drift ? -h * 0.18 : h * 0.06)

                orb(Theme.indigo.opacity(0.40 * intensity), size: w * 0.95)
                    .offset(x: drift ? w * 0.30 : -w * 0.22,
                            y: drift ?  h * 0.24 :  h * 0.44)

                orb(Theme.gold.opacity(0.16 * intensity), size: w * 0.72)
                    .offset(x: drift ? -w * 0.16 : w * 0.26,
                            y: drift ?  h * 0.62 :  h * 0.30)

                orb(Theme.teal.opacity(0.22 * intensity), size: w * 0.62)
                    .offset(x: drift ?  w * 0.24 : -w * 0.10,
                            y: drift ? -h * 0.30 :  h * 0.14)

                // Grain géométrique : casse le dégradé et signe le thème.
                IslamicPattern(tile: 92, opacity: 0.05)
                    .ignoresSafeArea()

                // Vignettage : ramène le regard vers le centre.
                RadialGradient(
                    colors: [.clear, Theme.night.opacity(0.55)],
                    center: .center, startRadius: w * 0.32, endRadius: w * 1.05
                )
                .ignoresSafeArea()
                .blendMode(.multiply)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 19).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .ignoresSafeArea()
        .drawingGroup(opaque: false)
    }

    private func orb(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size * 0.30)
    }
}

// MARK: - Ornement géométrique

/// Entrelacs de rosettes à huit branches, tracé au `Canvas`.
/// Motif purement vectoriel : aucun asset, net à toute densité d'écran.
struct IslamicPattern: View {
    var tile: CGFloat = 88
    var lineWidth: CGFloat = 0.7
    var color: Color = .white
    var opacity: Double = 0.06

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { ctx, size in
            guard tile > 8 else { return }
            let cols = Int((size.width / tile).rounded(.up)) + 2
            let rows = Int((size.height / tile).rounded(.up)) + 2

            var stars = Path()
            var links = Path()

            for r in 0..<rows {
                for c in 0..<cols {
                    // Une ligne sur deux est décalée d'un demi-pas : maille en quinconce.
                    let dx = r.isMultiple(of: 2) ? 0 : tile / 2
                    let center = CGPoint(x: CGFloat(c) * tile + dx - tile,
                                        y: CGFloat(r) * tile - tile)
                    stars.addPath(Self.star(center: center, outer: tile * 0.40, points: 8))
                    links.addPath(Self.polygon(center: center, radius: tile * 0.17, sides: 8))
                }
            }
            ctx.stroke(stars, with: .color(color.opacity(opacity)), lineWidth: lineWidth)
            ctx.stroke(links, with: .color(color.opacity(opacity * 0.75)), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }

    /// Étoile à `points` branches (rosette girih).
    static func star(center: CGPoint, outer: CGFloat, points: Int) -> Path {
        var p = Path()
        let inner = outer * 0.56
        let step = Double.pi / Double(points)
        for i in 0..<(points * 2) {
            let a = Double(i) * step - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: center.x + r * CGFloat(cos(a)),
                            y: center.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func polygon(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var p = Path()
        let step = 2 * Double.pi / Double(sides)
        for i in 0..<sides {
            let a = Double(i) * step - .pi / 2
            let pt = CGPoint(x: center.x + radius * CGFloat(cos(a)),
                            y: center.y + radius * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Formes

/// Octogone régulier — cartouche des numéros de sourate.
struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * (.pi / 4) - .pi / 8
            let pt = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Arc mihrab — encadre le monogramme des récitateurs.
struct MihrabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let shoulder = h * 0.42
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: shoulder))
        p.addCurve(to: CGPoint(x: w / 2, y: 0),
                   control1: CGPoint(x: 0, y: shoulder * 0.30),
                   control2: CGPoint(x: w * 0.20, y: 0))
        p.addCurve(to: CGPoint(x: w, y: shoulder),
                   control1: CGPoint(x: w * 0.80, y: 0),
                   control2: CGPoint(x: w, y: shoulder * 0.30))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}
