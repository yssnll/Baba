import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Palette et typographie de l'application.
///
/// Registre chromatique : nuit profonde (fond), émeraude (accent vivant),
/// or (ornements, calligraphie), ivoire (texte). Volontairement sobre :
/// la couleur sert la lisibilité, l'ornement vient de la géométrie et du verre.
enum Theme {

    // MARK: Fonds
    static var night: Color { AppearanceSettings.shared.background }
    static var nightSoft: Color { AppearanceSettings.shared.surface }
    static var deep: Color {
        AppearanceSettings.shared.background
            .opacity(0.82)
    }

    // MARK: Accents
    static var emerald: Color { AppearanceSettings.shared.success }
    static var emeraldDeep: Color { AppearanceSettings.shared.accent.opacity(0.72) }
    static var teal: Color {
        AppearanceSettings.shared.accent
            .mixing(with: AppearanceSettings.shared.success, amount: 0.45)
    }
    static var indigo: Color { AppearanceSettings.shared.accent.opacity(0.78) }

    // MARK: Or
    static var gold: Color { AppearanceSettings.shared.gold }
    static var goldLight: Color {
        AppearanceSettings.shared.gold
            .mixing(with: AppearanceSettings.shared.text, amount: 0.35)
    }
    static var goldDeep: Color {
        AppearanceSettings.shared.gold
            .mixing(with: AppearanceSettings.shared.background, amount: 0.42)
    }

    // MARK: Texte
    static var ivory: Color { AppearanceSettings.shared.text }
    static var muted: Color { AppearanceSettings.shared.muted }
    static var faint: Color { AppearanceSettings.shared.muted.opacity(0.68) }

    // MARK: États
    static var danger: Color { AppearanceSettings.shared.danger }

    // MARK: Dégradés

    /// Fond principal de l'application.
    static var canvas: LinearGradient {
        LinearGradient(
        colors: [night, nightSoft, deep],
        startPoint: .top,
        endPoint: .bottom
        )
    }

    /// Dégradé d'accent, utilisé pour les pastilles et le bouton de lecture.
    static var accent: LinearGradient {
        LinearGradient(
        colors: [emerald, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
        )
    }

    /// Dégradé doré des ornements et de la calligraphie.
    static var goldSheen: LinearGradient {
        LinearGradient(
        colors: [goldLight, gold, goldDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
        )
    }

    /// Reflet spéculaire : donne au verre son arête lumineuse.
    static let specular = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.55), location: 0.00),
            .init(color: .white.opacity(0.10), location: 0.35),
            .init(color: .white.opacity(0.02), location: 0.62),
            .init(color: .white.opacity(0.22), location: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Voile teinté posé sur le matériau flou pour éviter le gris plat.
    static var glassTint: LinearGradient {
        LinearGradient(
        colors: [.white.opacity(0.13), .white.opacity(0.04), Theme.emerald.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
        )
    }

    // MARK: Typographie

    /// Titres latins — serif, pour une tenue proche de l'édition imprimée.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Texte courant — arrondi, plus doux à l'écran.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Chiffres alignés, indispensable pour les compteurs et durées.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Noms de sourates en arabe. La police système gère le script,
    /// `.serif` en donne le rendu le plus proche du naskh.
    static func arabic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Métriques
    static let radiusCard: CGFloat = 22
    static let radiusSheet: CGFloat = 34
    static let radiusPill: CGFloat = 16
    static let gutter: CGFloat = 18
}

// MARK: - Formatage

enum Fmt {
    /// Secondes → `m:ss` (ou `h:mm:ss` au-delà de l'heure).
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    static func bytes(_ count: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useMB, .useGB, .useKB]
        return f.string(fromByteCount: count)
    }
}
