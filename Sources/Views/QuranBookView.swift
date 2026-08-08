import SwiftUI
import Combine
import UIKit

@MainActor
final class QuranBookStore: ObservableObject {
    @Published private(set) var verses: [QuranBookVerse] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadedSurahNumber: Int?

    private var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    func load(surahNumber: Int) {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        verses = []

        loadTask = Task { [weak self] in
            do {
                let document = try await QuranBookService.load(
                    surahNumber: surahNumber
                )
                try Task.checkCancellation()
                self?.verses = document.verses
                self?.loadedSurahNumber = surahNumber
                self?.isLoading = false
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        }
    }
}

struct QuranBookView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @StateObject private var book = QuranBookStore()
    @AppStorage("tilawa.book.surah") private var selectedSurahNumber = 1

    private var selectedSurah: Surah? {
        catalog.surah(selectedSurahNumber) ?? catalog.surahs.first
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        header

                        if let errorMessage = book.errorMessage {
                            errorState(errorMessage)
                        } else if book.isLoading {
                            loadingState
                        } else if book.verses.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: "Choisis une sourate",
                                message: "Le texte vérifié de la sourate apparaîtra ici."
                            )
                        } else {
                            TajweedLegend()
                                .padding(.top, 2)
                            QuranContinuousText(verses: book.verses)
                                .id("quran-continuous-text")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .onChange(of: book.verses.count) { _, _ in
                    guard !book.verses.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        scrollProxy.scrollTo("quran-continuous-text", anchor: .top)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadCurrentSelection()
        }
        .onChange(of: catalog.surahs.count) { _, _ in
            loadCurrentSelection()
        }
        .onChange(of: selectedSurahNumber) { _, _ in
            loadCurrentSelection()
        }
    }

    private var header: some View {
        VStack(spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Livre")
                        .font(Theme.display(28, .bold))
                        .foregroundStyle(Theme.goldSheen)
                    Text("Le Coran · Hafs")
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(Theme.faint)
                }

                Spacer(minLength: 12)

                Text("القرآن")
                    .font(Theme.arabic(29, .semibold))
                    .foregroundStyle(Theme.ivory.opacity(0.92))
            }
            .padding(.top, 8)

            OrnamentDivider()
            controls
            sourceNotice
        }
        .padding(.bottom, 4)
    }

    private var controls: some View {
        VStack(spacing: 9) {
            Menu {
                ForEach(catalog.surahs) { surah in
                    Button {
                        selectedSurahNumber = surah.number
                    } label: {
                        Label(
                            "\(surah.number). \(surah.nameFr) · \(surah.nameAr)",
                            systemImage: selectedSurahNumber == surah.number
                                ? "checkmark"
                                : "book.closed"
                        )
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    SurahMedallion(number: selectedSurah?.number ?? selectedSurahNumber, side: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedSurah?.nameFr ?? "Sourate \(selectedSurahNumber)")
                            .font(Theme.ui(14, .semibold))
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(1)
                        Text(selectedSurah?.nameAr ?? "السورة")
                            .font(Theme.arabic(14))
                            .foregroundStyle(Theme.gold.opacity(0.78))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .glass(radius: Theme.radiusPill, elevation: 0.55)
            }
            .buttonStyle(.plain)
            .disabled(catalog.surahs.isEmpty)
        }
    }

    private var sourceNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.emerald)
            Text(QuranBookRiwaya.hafs.sourceDescription)
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.gold)
                .scaleEffect(1.1)
            Text("Chargement du texte vérifié…")
                .font(Theme.ui(12.5, .medium))
                .foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 11) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.gold)
            Text("Texte indisponible")
                .font(Theme.display(17, .semibold))
                .foregroundStyle(Theme.ivory)
            Text(message)
                .font(Theme.ui(12.5, .regular))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                loadCurrentSelection()
            }
            .font(Theme.ui(12, .semibold))
            .foregroundStyle(Theme.night)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.goldSheen))
            .buttonStyle(PressScale(scale: 0.96))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .glass(radius: Theme.radiusCard, elevation: 0.5)
    }

    private func loadCurrentSelection() {
        guard !catalog.surahs.isEmpty else { return }

        // Une ancienne valeur enregistrée ne doit jamais empêcher le Livre de
        // démarrer. Cela arrivait après une mise à jour lorsque le numéro
        // mémorisé ne correspondait plus au catalogue chargé.
        guard let surah = catalog.surah(selectedSurahNumber)
                ?? catalog.surahs.first else { return }

        if selectedSurahNumber != surah.number {
            selectedSurahNumber = surah.number
        }

        // Évite de relancer une requête quand SwiftUI réévalue la vue sans
        // changement de sourate.
        guard book.loadedSurahNumber != surah.number || book.errorMessage != nil
        else { return }
        book.load(surahNumber: surah.number)
    }
}

private struct QuranContinuousText: View {
    let verses: [QuranBookVerse]

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TajweedText(rawValue: verses.map { verse in
                let text = verse.tajweedText ?? verse.plainText
                // Quran.com inclut déjà le marqueur du verset dans le texte
                // tajwid. On ne l'ajoute que pour les réponses de secours.
                return text.contains("<span class=end>")
                    ? text
                    : "\(text) <span class=end> ۝\(verse.verseNumber) </span>"
            }.joined(separator: " "))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct TajweedText: View {
    let rawValue: String

    var body: some View {
        QuranRichTextLabel(rawValue: rawValue)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct QuranRichTextLabel: UIViewRepresentable {
    let rawValue: String

    func makeUIView(context: Context) -> QuranUILabel {
        let label = QuranUILabel()
        label.numberOfLines = 0
        label.textAlignment = .right
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.attributedText = makeAttributedText(from: rawValue)
        return label
    }

    func updateUIView(_ label: QuranUILabel, context: Context) {
        label.attributedText = makeAttributedText(from: rawValue)
        label.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: QuranUILabel,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        // UILabel ne connaît pas sa largeur lorsqu'il est placé dans un
        // ScrollView vertical. Sans cette mesure explicite, UIKit conserve
        // parfois une hauteur correspondant à une seule ligne et le texte
        // déborde horizontalement au lieu de s'enrouler.
        uiView.preferredMaxLayoutWidth = width
        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(fittingSize.height))
    }

    private func makeAttributedText(from raw: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineSpacing = 12
        paragraph.baseWritingDirection = .rightToLeft

        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: QuranUILabel.quranFont,
            .foregroundColor: UIColor(Theme.ivory),
            .paragraphStyle: paragraph
        ]
        let result = NSMutableAttributedString(string: "", attributes: defaultAttributes)

        let pattern = #"<tajweed class=([^>]+)>(.*?)</tajweed>|<span class=end>(.*?)</span>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return NSAttributedString(string: raw, attributes: defaultAttributes)
        }

        let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let matches = regex.matches(in: raw, options: [], range: nsRange)
        var cursor = raw.startIndex

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: raw) else { continue }
            if cursor < fullRange.lowerBound {
                result.append(
                    NSAttributedString(
                        string: String(raw[cursor..<fullRange.lowerBound]),
                        attributes: defaultAttributes
                    )
                )
            }

            let className = match.range(at: 1).location == NSNotFound
                ? "end"
                : (Range(match.range(at: 1), in: raw).map { String(raw[$0]) } ?? "")
            let contentRange = match.range(at: 2).location == NSNotFound
                ? match.range(at: 3)
                : match.range(at: 2)
            let content = Range(contentRange, in: raw).map { String(raw[$0]) } ?? ""

            var attributes = defaultAttributes
            attributes[.foregroundColor] = UIColor(color(for: className))
            result.append(NSAttributedString(string: content, attributes: attributes))
            cursor = fullRange.upperBound
        }

        if cursor < raw.endIndex {
            result.append(
                NSAttributedString(
                    string: String(raw[cursor...]),
                    attributes: defaultAttributes
                )
            )
        }
        return result
    }

    private func color(for className: String) -> Color {
        switch className {
        case "madda_normal":
            return TajweedPalette.maddTwo
        case "madda_permissible":
            return TajweedPalette.maddTwoFourSix
        case "madda_obligatory":
            return TajweedPalette.maddFive
        case "madda_necessary":
            return TajweedPalette.maddSix
        case "qalaqah":
            return TajweedPalette.qalqalah
        case "ham_wasl", "laam_shamsiyah", "idgham", "idgham_shafawi":
            return TajweedPalette.silent
        case "ikhfa", "ikhfa_shafawi", "iqlab", "ghunnah", "idgham_ghunnah":
            return TajweedPalette.ikhfaGhunnah
        case "tafkhim":
            return TajweedPalette.tafkhim
        case "end":
            return Theme.gold
        default:
            return Theme.ivory
        }
    }
}

private final class QuranUILabel: UILabel {
    static let quranFont = UIFont(name: "GeezaPro", size: 23)
        ?? UIFont.systemFont(ofSize: 23, weight: .regular)

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, preferredMaxLayoutWidth != bounds.width else { return }
        preferredMaxLayoutWidth = bounds.width
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if size.width > 0 {
            preferredMaxLayoutWidth = size.width
        }
        return super.sizeThatFits(size)
    }
}

private struct TajweedLegend: View {
    private struct LegendItem: Identifiable {
        let id: String
        let title: String
        let color: Color
    }

    private let items: [LegendItem] = [
        LegendItem(id: "maddSix", title: "Madd 6 · obligatoire", color: TajweedPalette.maddSix),
        LegendItem(id: "maddFive", title: "Madd 5 · wajib", color: TajweedPalette.maddFive),
        LegendItem(id: "maddTwoFourSix", title: "Madd 2/4/6 · permis", color: TajweedPalette.maddTwoFourSix),
        LegendItem(id: "maddTwo", title: "Madd 2/4", color: TajweedPalette.maddTwo),
        LegendItem(id: "ikhfa", title: "Ikhfa · ghunnah", color: TajweedPalette.ikhfaGhunnah),
        LegendItem(id: "silent", title: "Idgham · non prononcé", color: TajweedPalette.silent),
        LegendItem(id: "tafkhim", title: "Tafkhim", color: TajweedPalette.tafkhim),
        LegendItem(id: "qalqalah", title: "Qalqalah", color: TajweedPalette.qalqalah)
    ]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(Theme.ui(9.5, .medium))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private enum TajweedPalette {
    static let maddSix = Color(hex: 0x8E3D68)
    static let maddFive = Color(hex: 0xC65A73)
    static let maddTwoFourSix = Color(hex: 0xB86B59)
    static let maddTwo = Color(hex: 0xC7834B)
    static let ikhfaGhunnah = Color(hex: 0x3D9B77)
    static let silent = Color(hex: 0x9AA3A7)
    static let tafkhim = Color(hex: 0x347E92)
    static let qalqalah = Color(hex: 0x218FC4)
}