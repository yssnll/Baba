import SwiftUI
import WidgetKit

struct TilawaWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let isPlaying: Bool
    let hasTrack: Bool
}

struct TilawaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TilawaWidgetEntry {
        TilawaWidgetEntry(
            date: Date(), title: "Reprendre la lecture",
            subtitle: "Tilawa", isPlaying: false, hasTrack: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TilawaWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<TilawaWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> TilawaWidgetEntry {
        let defaults = UserDefaults(suiteName: TilawaSharedState.appGroup)
        let title = defaults?.string(forKey: TilawaSharedState.widgetTitle)
        let subtitle = defaults?.string(forKey: TilawaSharedState.widgetSubtitle)
        return TilawaWidgetEntry(
            date: Date(),
            title: title ?? "Reprendre la lecture",
            subtitle: subtitle ?? "Ouvre Tilawa pour commencer",
            isPlaying: defaults?.bool(forKey: TilawaSharedState.widgetIsPlaying) ?? false,
            hasTrack: title != nil
        )
    }
}

struct TilawaWidgetView: View {
    let entry: TilawaWidgetEntry

    private var toggleURL: URL {
        URL(string: entry.hasTrack ? "tilawa://toggle" : "tilawa://resume")!
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.11, blue: 0.15),
                         Color(red: 0.03, green: 0.20, blue: 0.17)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.28))
                    Text("TILAWA")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Text("3.4")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)

                Text(entry.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(entry.subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Link(destination: URL(string: "tilawa://previous")!) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Link(destination: toggleURL) {
                        Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.12))
                            .frame(width: 31, height: 31)
                            .background(Circle().fill(Color(red: 0.95, green: 0.72, blue: 0.28)))
                    }
                    Link(destination: URL(string: "tilawa://next")!) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                }
            }
            .padding(15)
        }
        .widgetURL(URL(string: "tilawa://resume")!)
        .containerBackground(for: .widget) {
            Color(red: 0.03, green: 0.12, blue: 0.12)
        }
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TilawaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TilawaWidget()
    }
}