import SwiftUI
import WidgetKit
import AppIntents

struct TilawaWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let isPlaying: Bool
    let hasTrack: Bool
    let position: Double
    let duration: Double
    let updatedAt: TimeInterval
    let palette: TilawaWidgetPalette
}

struct TilawaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TilawaWidgetEntry {
        TilawaWidgetEntry(
            date: Date(), title: "Reprendre la lecture",
            subtitle: "Tilawa", isPlaying: true, hasTrack: true,
            position: 42, duration: 240,
            updatedAt: Date().timeIntervalSince1970,
            palette: .fallback
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TilawaWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<TilawaWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // L'application demande un rechargement à chaque changement d'état.
        // Cette échéance est un filet de sécurité si WidgetKit retarde ou
        // regroupe la demande de reload.
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(15))
            )
        )
    }

    private func currentEntry() -> TilawaWidgetEntry {
        let defaults = UserDefaults(suiteName: TilawaSharedState.appGroup)
        let snapshot = defaults?.data(forKey: TilawaSharedState.widgetSnapshot)
            .flatMap { try? JSONDecoder().decode(TilawaWidgetSnapshot.self, from: $0) }
        return TilawaWidgetEntry(
            date: snapshot.map { Date(timeIntervalSince1970: $0.updatedAt) } ?? Date(),
            title: snapshot?.hasTrack == true ? (snapshot?.title ?? "Récitation") : "Aucune lecture",
            subtitle: snapshot?.hasTrack == true
                ? (snapshot?.subtitle ?? "Prêt à reprendre")
                : "Lance une récitation dans Tilawa",
            isPlaying: snapshot?.isPlaying ?? false,
            hasTrack: snapshot?.hasTrack ?? false,
            position: snapshot?.position ?? 0,
            duration: snapshot?.duration ?? 0,
            updatedAt: snapshot?.updatedAt ?? Date().timeIntervalSince1970,
            palette: TilawaWidgetPalette(defaults: defaults)
        )
    }
}

struct TilawaWidgetView: View {
    let entry: TilawaWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            ZStack {
                background
                switch family {
                case .systemSmall:
                    smallLayout(at: context.date)
                case .systemMedium:
                    mediumLayout(at: context.date)
                default:
                    largeLayout(at: context.date)
                }
            }
            .widgetURL(URL(string: "tilawa://resume")!)
            .containerBackground(for: .widget) {
                entry.palette.background
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [entry.palette.background, entry.palette.surface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [entry.palette.accent.opacity(0.34), .clear],
                center: .topTrailing, startRadius: 2, endRadius: 180
            )
            Circle()
                .stroke(entry.palette.gold.opacity(0.18), lineWidth: 1)
                .frame(width: 170, height: 170)
                .offset(x: 120, y: -92)
            Circle()
                .fill(entry.palette.success.opacity(0.11))
                .frame(width: 130, height: 130)
                .offset(x: -110, y: 95)
        }
    }

    private var brand: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.palette.gold)
            Text("TILAWA")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(entry.palette.text.opacity(0.82))
            Spacer()
            Circle()
                .fill(entry.isPlaying ? entry.palette.success : entry.palette.muted.opacity(0.7))
                .frame(width: 7, height: 7)
        }
    }

    private var trackTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(entry.palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(entry.subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(entry.palette.muted)
                .lineLimit(1)
        }
    }

    private func displayedPosition(at date: Date) -> Double {
        guard entry.isPlaying else { return entry.position }
        let elapsed = max(0, date.timeIntervalSince1970 - entry.updatedAt)
        return min(entry.position + elapsed, entry.duration > 0 ? entry.duration : .greatestFiniteMagnitude)
    }

    private func progress(at date: Date) -> some View {
        GeometryReader { proxy in
            let fraction = entry.duration > 0
                ? min(max(displayedPosition(at: date) / entry.duration, 0), 1)
                : 0
            ZStack(alignment: .leading) {
                Capsule().fill(entry.palette.text.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(
                        colors: [entry.palette.gold, entry.palette.accent],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 4)
    }

    private var playButtonLabel: some View {
        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(entry.palette.background)
            .frame(width: 34, height: 34)
            .background(Circle().fill(entry.palette.gold))
            .shadow(color: entry.palette.gold.opacity(0.25), radius: 7)
    }

    @ViewBuilder
    private var playButton: some View {
        if entry.hasTrack {
            Button(intent: TilawaTogglePlaybackIntent()) {
                playButtonLabel
            }
        } else {
            Button(intent: TilawaResumePlaybackIntent()) {
                playButtonLabel
            }
        }
    }

    private func smallLayout(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            brand
            Spacer(minLength: 2)
            trackTitle
            progress(at: date)
            HStack {
                Text(entry.isPlaying ? "Lecture en cours" : "En pause")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.palette.muted)
                Spacer()
                playButton
            }
        }
        .padding(14)
    }

    private func mediumLayout(at date: Date) -> some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 10) {
                brand
                Spacer(minLength: 0)
                trackTitle
                progress(at: date)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Image(systemName: entry.isPlaying ? "waveform" : "headphones")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(entry.palette.gold)
                HStack(spacing: 8) {
                    Button(intent: TilawaPreviousTrackIntent()) {
                        Image(systemName: "backward.end.fill")
                    }
                    playButton
                    Button(intent: TilawaNextTrackIntent()) {
                        Image(systemName: "forward.end.fill")
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(entry.palette.text.opacity(0.85))
            }
        }
        .padding(16)
    }

    private func largeLayout(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            brand
            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(entry.palette.accent.opacity(0.28))
                        .frame(width: 58, height: 58)
                    Image(systemName: entry.isPlaying ? "waveform" : "moon.stars.fill")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(entry.palette.gold)
                }
                trackTitle
            }
            progress(at: date)
            HStack(spacing: 18) {
                Button(intent: TilawaPreviousTrackIntent()) {
                    Image(systemName: "backward.end.fill")
                }
                playButton
                Button(intent: TilawaNextTrackIntent()) {
                    Image(systemName: "forward.end.fill")
                }
                Spacer()
                Text(entry.isPlaying ? "En lecture" : "En pause")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.palette.muted)
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(entry.palette.text.opacity(0.85))
        }
        .padding(18)
    }
}

struct TilawaTogglePlaybackIntent: AppIntent {
    static let title: LocalizedStringResource = "Lire ou mettre en pause"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TilawaWidgetCommandStore.send(.toggle)
        return .result()
    }
}

struct TilawaResumePlaybackIntent: AppIntent {
    static let title: LocalizedStringResource = "Reprendre la lecture"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TilawaWidgetCommandStore.send(.toggle)
        return .result()
    }
}

struct TilawaPreviousTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Sourate précédente"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TilawaWidgetCommandStore.send(.previous)
        return .result()
    }
}

struct TilawaNextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Sourate suivante"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TilawaWidgetCommandStore.send(.next)
        return .result()
    }
}

struct TilawaWidgetPalette {
    let background: Color
    let surface: Color
    let accent: Color
    let gold: Color
    let text: Color
    let muted: Color
    let success: Color

    private init(
        background: Color,
        surface: Color,
        accent: Color,
        gold: Color,
        text: Color,
        muted: Color,
        success: Color
    ) {
        self.background = background
        self.surface = surface
        self.accent = accent
        self.gold = gold
        self.text = text
        self.muted = muted
        self.success = success
    }

    static let fallback = TilawaWidgetPalette(
        background: Color(hex: "#100D19"),
        surface: Color(hex: "#211A2D"),
        accent: Color(hex: "#B98A42"),
        gold: Color(hex: "#E9C46A"),
        text: Color(hex: "#F6F0E6"),
        muted: Color(hex: "#B8ADBF"),
        success: Color(hex: "#6BC4A3")
    )

    init(defaults: UserDefaults?) {
        self.init(
            background: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceBackground) ?? "#100D19"),
            surface: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceSurface) ?? "#211A2D"),
            accent: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceAccent) ?? "#B98A42"),
            gold: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceGold) ?? "#E9C46A"),
            text: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceText) ?? "#F6F0E6"),
            muted: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceMuted) ?? "#B8ADBF"),
            success: Color(hex: defaults?.string(forKey: TilawaSharedState.appearanceSuccess) ?? "#6BC4A3")
        )
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.replacingOccurrences(of: "#", with: "")
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}

struct TilawaWidget: Widget {
    let kind = "TilawaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TilawaWidgetProvider()) { entry in
            TilawaWidgetView(entry: entry)
        }
        .configurationDisplayName("Tilawa")
        .description("Reprends ou contrôle ta récitation depuis l'écran d'accueil.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct TilawaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TilawaWidget()
    }
}