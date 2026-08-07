import SwiftUI

// MARK: - Monogramme de récitateur

/// Emblème visuel distinct pour chaque récitateur, sans dépendre d'une photo.
struct Monogram: View {
    let reciter: Reciter
    var side: CGFloat = 54

    @ObservedObject private var appearance = AppearanceSettings.shared

    private var seed: Int {
        reciter.id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
    }

    private var initials: String {
        let parts = reciter.name
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .prefix(2)
        let value = parts.map { String($0.prefix(1)) }.joined()
        return value.isEmpty ? "ت" : value.uppercased()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [appearance.accent.opacity(0.95), appearance.surface],
                        startPoint: seed.isMultiple(of: 2) ? .topLeading : .bottomLeading,
                        endPoint: seed.isMultiple(of: 2) ? .bottomTrailing : .topTrailing
                    )
                )

            Circle()
                .stroke(appearance.gold.opacity(0.62), lineWidth: max(1, side * 0.025))
                .padding(side * 0.105)

            Circle()
                .fill(appearance.background.opacity(0.20))
                .frame(width: side * 0.62, height: side * 0.62)

            VStack(spacing: side * 0.01) {
                Text(initials)
                    .font(.system(size: side * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(appearance.text)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                if reciter.hasArabicName {
                    Text(String(reciter.nameAr.prefix(8)))
                        .font(.system(size: side * 0.12, weight: .medium, design: .serif))
                        .foregroundStyle(appearance.gold.opacity(0.92))
                        .lineLimit(1)
                }
            }

            HStack(spacing: side * 0.035) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(appearance.gold.opacity(0.72))
                        .frame(width: max(1.5, side * 0.025),
                               height: side * CGFloat(0.10 + Double((seed + index) & 1) * 0.07))
                }
            }
            .offset(y: side * 0.34)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: side * 0.29, style: .continuous)
                .stroke(appearance.gold.opacity(0.24), lineWidth: 0.8)
        }
        .shadow(color: appearance.background.opacity(0.42),
                radius: side * 0.15, y: side * 0.08)
        .accessibilityLabel("Logo de \(reciter.name)")
    }
}

// MARK: - Médaillon de sourate

struct SurahMedallion: View {
    let number: Int
    var active: Bool = false
    var side: CGFloat = 42

    var body: some View {
        ZStack {
            Octagon()
                .fill(active
                      ? AnyShapeStyle(Theme.accent)
                      : AnyShapeStyle(Color.white.opacity(0.06)))
            Octagon()
                .stroke(active ? Theme.goldLight.opacity(0.85) : Theme.gold.opacity(0.38),
                        lineWidth: 0.9)
            Text("\(number)")
                .font(Theme.mono(side * 0.34, .semibold))
                .foregroundStyle(active ? Theme.ivory : Theme.muted)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Anneau de progression

struct ProgressRing: View {
    var fraction: Double
    var side: CGFloat = 26
    var lineWidth: CGFloat = 2.4

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(fraction, 1)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: fraction)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Bouton de téléchargement

/// Bouton unique dont l'icône traduit l'état : à télécharger, en cours, présent, échec.
struct DownloadButton: View {
    let state: DownloadState
    var side: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                switch state {
                case .idle:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: side * 0.76, weight: .light))
                        .foregroundStyle(Theme.faint)

                case .waiting:
                    ProgressRing(fraction: 0.04, side: side * 0.82)
                        .opacity(0.7)

                case .downloading(let p):
                    ZStack {
                        ProgressRing(fraction: p, side: side * 0.82)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Theme.ivory.opacity(0.85))
                            .frame(width: side * 0.20, height: side * 0.20)
                    }

                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: side * 0.76))
                        .foregroundStyle(Theme.emerald)

                case .failed:
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: side * 0.76, weight: .light))
                        .foregroundStyle(Theme.danger)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

// MARK: - Pastilles

struct Chip: View {
    let text: String
    var icon: String?
    var tint: Color = Theme.muted

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(Theme.ui(10.5, .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.22), lineWidth: 0.7)
        )
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(title).font(Theme.ui(12.5, .semibold))
            }
            .foregroundStyle(selected ? Theme.night : Theme.ivory.opacity(0.82))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule().fill(Theme.goldSheen)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Color.white.opacity(0.05))
                }
            }
            .overlay(
                Capsule().stroke(selected ? .clear : Color.white.opacity(0.16), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Champ de recherche

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Rechercher un récitateur…"

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.faint)

            TextField(placeholder, text: $text)
                .font(Theme.ui(15, .regular))
                .foregroundStyle(Theme.ivory)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .glass(radius: Theme.radiusPill, elevation: 0.55)
    }
}

// MARK: - Boutons de transport

struct CircleGlassButton: View {
    let icon: String
    var side: CGFloat = 46
    var iconScale: CGFloat = 0.40
    var prominent: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if prominent {
                    Circle().fill(Theme.accent)
                    Circle().stroke(Theme.goldLight.opacity(0.5), lineWidth: 1)
                } else {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Color.white.opacity(0.06))
                    Circle().stroke(Theme.specular, lineWidth: 0.9)
                }
                Image(systemName: icon)
                    .font(.system(size: side * iconScale, weight: .semibold))
                    .foregroundStyle(Theme.ivory)
            }
            .frame(width: side, height: side)
            .shadow(color: prominent ? Theme.emerald.opacity(0.42) : .black.opacity(0.28),
                    radius: prominent ? 16 : 8, y: 5)
            .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(PressScale())
        .disabled(disabled)
    }
}

/// Retour tactile discret : l'élément s'enfonce légèrement à l'appui.
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.93
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - Titres de section

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(17, .semibold))
                    .foregroundStyle(Theme.ivory)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(Theme.faint)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(Theme.gold.opacity(0.75))
            }
        }
    }
}

/// Filet ornemental : deux traits dorés et un losange, séparateur de sections.
struct OrnamentDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            line
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(Theme.gold.opacity(0.6))
            line
        }
        .frame(height: 10)
    }

    private var line: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [.clear, Theme.gold.opacity(0.35), .clear],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(height: 0.8)
    }
}

// MARK: - État vide

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                Octagon()
                    .stroke(Theme.gold.opacity(0.35), lineWidth: 1)
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(Theme.gold.opacity(0.7))
            }
            Text(title)
                .font(Theme.display(17, .semibold))
                .foregroundStyle(Theme.ivory)
            Text(message)
                .font(Theme.ui(13, .regular))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }
}
