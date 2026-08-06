import SwiftUI
import UIKit

/// Apparence personnalisable de Tilawa.
///
/// Les choix sont conservés localement afin de rester actifs après le
/// redémarrage de l'application.
final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    enum Preset: String, CaseIterable, Identifiable {
        case nocturne
        case emerald
        case sapphire
        case ruby
        case ivory
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .nocturne: return "Nocturne dorée"
            case .emerald: return "Jardin émeraude"
            case .sapphire: return "Bleu saphir"
            case .ruby: return "Rubis profond"
            case .ivory: return "Ivoire lumineux"
            case .custom: return "Personnalisée"
            }
        }

        var icon: String {
            switch self {
            case .nocturne: return "moon.stars.fill"
            case .emerald: return "leaf.fill"
            case .sapphire: return "drop.fill"
            case .ruby: return "flame.fill"
            case .ivory: return "sun.max.fill"
            case .custom: return "slider.horizontal.3"
            }
        }
    }

    @Published private(set) var preset: Preset
    @Published private(set) var backgroundHex: String
    @Published private(set) var surfaceHex: String
    @Published private(set) var accentHex: String
    @Published private(set) var goldHex: String
    @Published private(set) var textHex: String
    @Published private(set) var mutedHex: String
    @Published private(set) var successHex: String
    @Published private(set) var dangerHex: String

    private let defaults = UserDefaults.standard
    private var applyingPreset = false

    private init() {
        preset = Preset(rawValue: defaults.string(forKey: Keys.preset) ?? "") ?? .nocturne
        backgroundHex = defaults.string(forKey: Keys.background) ?? "#100D19"
        surfaceHex = defaults.string(forKey: Keys.surface) ?? "#211A2D"
        accentHex = defaults.string(forKey: Keys.accent) ?? "#B98A42"
        goldHex = defaults.string(forKey: Keys.gold) ?? "#E9C46A"
        textHex = defaults.string(forKey: Keys.text) ?? "#F6F0E6"
        mutedHex = defaults.string(forKey: Keys.muted) ?? "#B8ADBF"
        successHex = defaults.string(forKey: Keys.success) ?? "#6BC4A3"
        dangerHex = defaults.string(forKey: Keys.danger) ?? "#F07878"

        if defaults.string(forKey: Keys.preset) == nil {
            applyPreset(.nocturne, save: false)
        }
    }

    var background: Color { Color(hex: backgroundHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var accent: Color { Color(hex: accentHex) }
    var gold: Color { Color(hex: goldHex) }
    var text: Color { Color(hex: textHex) }
    var muted: Color { Color(hex: mutedHex) }
    var success: Color { Color(hex: successHex) }
    var danger: Color { Color(hex: dangerHex) }

    var isLight: Bool { preset == .ivory }

    func applyPreset(_ preset: Preset) {
        guard preset != .custom else { return }
        applyPreset(preset, save: true)
    }

    func setBackground(_ color: Color) { update(\.backgroundHex, color: color) }
    func setSurface(_ color: Color) { update(\.surfaceHex, color: color) }
    func setAccent(_ color: Color) { update(\.accentHex, color: color) }
    func setGold(_ color: Color) { update(\.goldHex, color: color) }

    private func applyPreset(_ preset: Preset, save: Bool) {
        applyingPreset = true
        self.preset = preset

        switch preset {
        case .nocturne:
            backgroundHex = "#100D19"
            surfaceHex = "#211A2D"
            accentHex = "#B98A42"
            goldHex = "#E9C46A"
            textHex = "#F6F0E6"
            mutedHex = "#B8ADBF"
            successHex = "#6BC4A3"
            dangerHex = "#F07878"
        case .emerald:
            backgroundHex = "#081713"
            surfaceHex = "#123029"
            accentHex = "#2E9B78"
            goldHex = "#C9D68A"
            textHex = "#F0F6ED"
            mutedHex = "#A8C0B5"
            successHex = "#74D2A1"
            dangerHex = "#F28C86"
        case .sapphire:
            backgroundHex = "#091321"
            surfaceHex = "#14263D"
            accentHex = "#3B82C4"
            goldHex = "#8FD1E8"
            textHex = "#EFF6FF"
            mutedHex = "#A9BBD0"
            successHex = "#6CCDBE"
            dangerHex = "#F28B9A"
        case .ruby:
            backgroundHex = "#1B0C13"
            surfaceHex = "#351722"
            accentHex = "#B84D63"
            goldHex = "#E5A16C"
            textHex = "#FFF1EC"
            mutedHex = "#C9AAB1"
            successHex = "#83C9A4"
            dangerHex = "#FF8A7A"
        case .ivory:
            backgroundHex = "#F6F0E6"
            surfaceHex = "#FFFDF8"
            accentHex = "#8B6330"
            goldHex = "#B47C2C"
            textHex = "#241B18"
            mutedHex = "#756963"
            successHex = "#327C61"
            dangerHex = "#B74B48"
        case .custom:
            break
        }

        applyingPreset = false
        if save { persist() }
    }

    private func update(
        _ keyPath: ReferenceWritableKeyPath<AppearanceSettings, String>,
        color: Color
    ) {
        guard let hex = color.hexString else { return }
        self[keyPath: keyPath] = hex
        if !applyingPreset { preset = .custom }
        persist()
    }

    private func persist() {
        defaults.set(preset.rawValue, forKey: Keys.preset)
        defaults.set(backgroundHex, forKey: Keys.background)
        defaults.set(surfaceHex, forKey: Keys.surface)
        defaults.set(accentHex, forKey: Keys.accent)
        defaults.set(goldHex, forKey: Keys.gold)
        defaults.set(textHex, forKey: Keys.text)
        defaults.set(mutedHex, forKey: Keys.muted)
        defaults.set(successHex, forKey: Keys.success)
        defaults.set(dangerHex, forKey: Keys.danger)
    }

    private enum Keys {
        static let preset = "tilawa.appearance.preset"
        static let background = "tilawa.appearance.background"
        static let surface = "tilawa.appearance.surface"
        static let accent = "tilawa.appearance.accent"
        static let gold = "tilawa.appearance.gold"
        static let text = "tilawa.appearance.text"
        static let muted = "tilawa.appearance.muted"
        static let success = "tilawa.appearance.success"
        static let danger = "tilawa.appearance.danger"
    }
}

extension Color {
    init(hex: String) {
        let value = hex.replacingOccurrences(of: "#", with: "")
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        guard value.count == 6 else {
            self = .black
            return
        }

        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    var hexString: String? {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            return nil
        }
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }

    func mixing(with other: Color, amount: Double) -> Color {
        let first = UIColor(self)
        let second = UIColor(other)
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0

        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: nil),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: nil) else {
            return self
        }

        let t = CGFloat(max(0, min(1, amount)))
        return Color(
            red: Double(r1 * (1 - t) + r2 * t),
            green: Double(g1 * (1 - t) + g2 * t),
            blue: Double(b1 * (1 - t) + b2 * t)
        )
    }
}