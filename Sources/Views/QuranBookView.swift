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
    @AppStorage("tilawa.book.lightMode") private var isLightMode = false

    private var colors: QuranBookColors {
        QuranBookColors(isLight: isLightMode)
    }

    private var selectedSurah: Surah? {
        catalog.surah(selectedSurahNumber) ?? catalog.surahs.first
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Color.clear
                            .frame(height: 0)
                            .id("quran-book-top")
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
                            TajweedLegend(colors: colors)
                                .padding(.top, 2)
                            if selectedSurah?.number != 9 {
                                QuranBasmala(colors: colors)
                            }
                            QuranContinuousText(
                                verses: book.verses,
                                surahNumber: selectedSurah?.number ?? selectedSurahNumber,
                                colors: colors
                            )
                                .id("quran-continuous-text")
                            bottomNavigation
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
                .background(colors.background)
                .onChange(of: book.verses.count) { _, _ in
                    guard !book.verses.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        scrollProxy.scrollTo("quran-continuous-text", anchor: .top)
                    }
                }
                .onChange(of: selectedSurahNumber) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollProxy.scrollTo("quran-book-top", anchor: .top)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .background(colors.background.ignoresSafeArea())
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
                        .foregroundStyle(colors.heading)
                    Text("Le Coran · Hafs")
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(colors.secondaryText)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isLightMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isLightMode ? "moon.fill" : "sun.max.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isLightMode ? "Sombre" : "Clair")
                                .font(Theme.ui(10, .semibold))
                        }
                        .foregroundStyle(colors.controlAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(colors.controlBackground)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(colors.border, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                    .accessibilityLabel(isLightMode ? "Passer au mode sombre" : "Passer au mode clair")

                    Text("القرآن")
                        .font(Theme.arabic(29, .semibold))
                        .foregroundStyle(colors.primaryText.opacity(0.92))
                }
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
            HStack(spacing: 7) {
                surahNavigationButton(
                    title: "Précédente",
                    systemImage: "chevron.left",
                    action: selectPreviousSurah
                )
                .disabled(previousSurah == nil)

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
                    surahPickerLabel
                }
                .frame(maxWidth: .infinity)
                .disabled(catalog.surahs.isEmpty)

                surahNavigationButton(
                    title: "Suivante",
                    systemImage: "chevron.right",
                    action: selectNextSurah
                )
                .disabled(nextSurah == nil)
            }
        }
    }

    private var surahPickerLabel: some View {
        HStack(spacing: 8) {
            SurahMedallion(number: selectedSurah?.number ?? selectedSurahNumber, side: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedSurah?.nameFr ?? "Sourate \(selectedSurahNumber)")
                    .font(Theme.ui(14, .semibold))
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(1)
                Text(selectedSurah?.nameAr ?? "السورة")
                    .font(Theme.arabic(14))
                    .foregroundStyle(colors.controlAccent.opacity(0.88))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(colors.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(colors.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusPill, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusPill, style: .continuous)
                .stroke(colors.border, lineWidth: 0.8)
        }
    }

    private func surahNavigationButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Theme.ui(9.5, .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(colors.controlAccent)
            .frame(minWidth: 52, minHeight: 47)
            .padding(.horizontal, 2)
            .background(colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(colors.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(PressScale(scale: 0.95))
        .accessibilityLabel(title)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 10) {
            surahNavigationButton(
                title: "Précédente",
                systemImage: "chevron.left",
                action: selectPreviousSurah
            )
            .disabled(previousSurah == nil)

            Spacer(minLength: 0)

            surahNavigationButton(
                title: "Suivante",
                systemImage: "chevron.right",
                action: selectNextSurah
            )
            .disabled(nextSurah == nil)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var currentSurahIndex: Int? {
        catalog.surahs.firstIndex { $0.number == selectedSurahNumber }
    }

    private var previousSurah: Surah? {
        guard let index = currentSurahIndex, index > 0 else { return nil }
        return catalog.surahs[index - 1]
    }

    private var nextSurah: Surah? {
        guard let index = currentSurahIndex, index + 1 < catalog.surahs.count
        else { return nil }
        return catalog.surahs[index + 1]
    }

    private func selectPreviousSurah() {
        guard let previousSurah else { return }
        selectedSurahNumber = previousSurah.number
    }

    private func selectNextSurah() {
        guard let nextSurah else { return }
        selectedSurahNumber = nextSurah.number
    }

    private var sourceNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.success)
            Text(QuranBookRiwaya.hafs.sourceDescription)
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(colors.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(colors.border, lineWidth: 0.8)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(colors.controlAccent)
                .scaleEffect(1.1)
            Text("Chargement du texte vérifié…")
                .font(Theme.ui(12.5, .medium))
                .foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 11) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(colors.controlAccent)
            Text("Texte indisponible")
                .font(Theme.display(17, .semibold))
                .foregroundStyle(colors.primaryText)
            Text(message)
                .font(Theme.ui(12.5, .regular))
                .foregroundStyle(colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                loadCurrentSelection()
            }
            .font(Theme.ui(12, .semibold))
            .foregroundStyle(colors.buttonText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(colors.buttonBackground))
            .buttonStyle(PressScale(scale: 0.96))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(colors.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .stroke(colors.border, lineWidth: 0.8)
        }
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

private struct QuranBasmala: View {
    let colors: QuranBookColors

    var body: some View {
        Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
            .font(Theme.arabic(25, .regular))
            .foregroundStyle(colors.heading)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colors.border, lineWidth: 0.8)
            }
            .accessibilityLabel("Basmala")
    }
}

private struct QuranContinuousText: View {
    let verses: [QuranBookVerse]
    let surahNumber: Int
    let colors: QuranBookColors

    private struct DisplayVerse: Identifiable {
        let verse: QuranBookVerse
        let displayedNumber: Int

        var id: Int { verse.id }
    }

    private var displayVerses: [DisplayVerse] {
        var result: [DisplayVerse] = []
        for verse in verses {
            // L'API Quran.com renvoie la basmala comme l'élément 1 de
            // la Fatiha. Elle est déjà affichée au-dessus et ne doit donc
            // pas réapparaître comme un verset numéroté.
            if surahNumber == 1, verse.verseNumber == 1 {
                continue
            }

            let displayedNumber = surahNumber == 1 && verse.verseNumber > 1
                ? verse.verseNumber - 1
                : verse.verseNumber
            result.append(
                DisplayVerse(verse: verse, displayedNumber: displayedNumber)
            )
        }
        return result
    }

    var body: some View {
        QuranVerseFlowLayout(spacing: 5, lineSpacing: colors.isLight ? 7 : 9) {
            ForEach(displayVerses) { item in
                QuranVerseText(
                    verse: item.verse,
                    displayedNumber: item.displayedNumber == item.verse.verseNumber
                        ? nil
                        : item.displayedNumber,
                    colors: colors
                )
            }
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(colors.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colors.border, lineWidth: 0.8)
            }
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Dispose les versets dans un flux de droite à gauche. Chaque verset reste
/// un label indépendant (donc son arabe ne peut pas être réordonné par les
/// versets voisins), mais les labels se suivent sur la même ligne tant que
/// l'espace disponible le permet.
private struct QuranVerseFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    private struct Line {
        var items: [(index: Int, size: CGSize)]
        var width: CGFloat
        var height: CGFloat
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let sizes = measuredSizes(for: subviews, width: proposal.width)
        let width = proposal.width ?? sizes.reduce(0) {
            max($0, $1.width)
        }
        let lines = makeLines(sizes: sizes, availableWidth: max(width, 1))
        return CGSize(
            width: width,
            height: lines.reduce(0) { $0 + $1.height }
                + lineSpacing * CGFloat(max(0, lines.count - 1))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = measuredSizes(for: subviews, width: bounds.width)
        let lines = makeLines(sizes: sizes, availableWidth: bounds.width)
        var y = bounds.minY

        for line in lines {
            var rightEdge = bounds.maxX
            for item in line.items {
                let x = rightEdge - item.size.width
                subviews[item.index].place(
                    // Coordonnées géométriques explicites : le premier
                    // verset de chaque ligne est toujours ancré à droite,
                    // sans dépendre de la résolution de "leading" par
                    // SwiftUI dans un environnement RTL.
                    at: CGPoint(x: x + item.size.width / 2, y: y),
                    anchor: .top,
                    proposal: ProposedViewSize(item.size)
                )
                rightEdge = x - spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func measuredSizes(
        for subviews: Subviews,
        width: CGFloat?
    ) -> [CGSize] {
        subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            guard let width, width > 0, ideal.width > width else {
                return ideal
            }
            return subview.sizeThatFits(
                ProposedViewSize(width: width, height: nil)
            )
        }
    }

    private func makeLines(
        sizes: [CGSize],
        availableWidth: CGFloat
    ) -> [Line] {
        var lines: [Line] = []
        var current = Line(items: [], width: 0, height: 0)

        for (index, size) in sizes.enumerated() {
            let proposedWidth = current.items.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.items.isEmpty, proposedWidth > availableWidth {
                lines.append(current)
                current = Line(items: [], width: 0, height: 0)
            }

            let nextWidth = current.items.isEmpty
                ? size.width
                : current.width + spacing + size.width
            current.items.append((index: index, size: size))
            current.width = nextWidth
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            lines.append(current)
        }
        return lines
    }
}

private struct QuranVerseText: View {
    let verse: QuranBookVerse
    let displayedNumber: Int?
    let colors: QuranBookColors

    private var rawText: String {
        let text = verse.tajweedText ?? verse.plainText
        let number = displayedNumber ?? verse.verseNumber
        let arabicNumber = number
            .description
            .replacingOccurrences(of: "0", with: "٠")
            .replacingOccurrences(of: "1", with: "١")
            .replacingOccurrences(of: "2", with: "٢")
            .replacingOccurrences(of: "3", with: "٣")
            .replacingOccurrences(of: "4", with: "٤")
            .replacingOccurrences(of: "5", with: "٥")
            .replacingOccurrences(of: "6", with: "٦")
            .replacingOccurrences(of: "7", with: "٧")
            .replacingOccurrences(of: "8", with: "٨")
            .replacingOccurrences(of: "9", with: "٩")

        guard let regex = try? NSRegularExpression(
            pattern: #"<span class=end>.*?</span>"#,
            options: [.dotMatchesLineSeparators]
        ) else {
            return "\(text) <span class=end> ۝\(arabicNumber) </span>"
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return "\(text) <span class=end> ۝\(arabicNumber) </span>"
        }

        return text.replacingCharacters(
            in: matchRange,
            with: "<span class=end> ۝\(arabicNumber) </span>"
        )
    }

    var body: some View {
        QuranRichTextLabel(rawValue: rawText, colors: colors)
    }
}

private struct QuranRichTextLabel: UIViewRepresentable {
    let rawValue: String
    let colors: QuranBookColors

    func makeUIView(context: Context) -> QuranUILabel {
        let label = QuranUILabel()
        label.numberOfLines = 0
        label.textAlignment = .right
        label.semanticContentAttribute = .forceRightToLeft
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
        paragraph.lineSpacing = colors.isLight ? 7 : 9
        paragraph.baseWritingDirection = .rightToLeft

        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: QuranUILabel.quranFont,
            .foregroundColor: UIColor(colors.primaryText),
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
            return colors.maddTwo
        case "madda_permissible":
            return colors.maddTwoFourSix
        case "madda_obligatory":
            return colors.maddFive
        case "madda_necessary":
            return colors.maddSix
        case "qalaqah":
            return colors.qalqalah
        case "ham_wasl", "laam_shamsiyah", "idgham", "idgham_shafawi":
            return colors.silent
        case "ikhfa", "ikhfa_shafawi", "iqlab", "ghunnah", "idgham_ghunnah":
            return colors.ikhfaGhunnah
        case "tafkhim":
            return colors.tafkhim
        case "end":
            return colors.verseMarker
        default:
            return colors.primaryText
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
    let colors: QuranBookColors

    private struct LegendItem: Identifiable {
        let id: String
        let title: String
        let color: Color
    }

    private var items: [LegendItem] {
        [
            LegendItem(id: "maddSix", title: "Madd 6 · obligatoire", color: colors.maddSix),
            LegendItem(id: "maddFive", title: "Madd 5 · wajib", color: colors.maddFive),
            LegendItem(id: "maddTwoFourSix", title: "Madd 2/4/6 · permis", color: colors.maddTwoFourSix),
            LegendItem(id: "maddTwo", title: "Madd 2/4", color: colors.maddTwo),
            LegendItem(id: "ikhfa", title: "Ikhfa · ghunnah", color: colors.ikhfaGhunnah),
            LegendItem(id: "silent", title: "Idgham · non prononcé", color: colors.silent),
            LegendItem(id: "tafkhim", title: "Tafkhim", color: colors.tafkhim),
            LegendItem(id: "qalqalah", title: "Qalqalah", color: colors.qalqalah)
        ]
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colors.controlAccent)
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(Theme.ui(9.5, .medium))
                            .foregroundStyle(colors.secondaryText)
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

private struct QuranBookColors {
    let isLight: Bool

    var background: Color {
        isLight ? Color(hex: 0xFCFBF7) : Theme.night
    }

    var controlBackground: Color {
        isLight ? Color(hex: 0xFFFFFF) : Color.white.opacity(0.045)
    }

    var primaryText: Color {
        isLight ? Color(hex: 0x20252B) : Theme.ivory
    }

    var secondaryText: Color {
        isLight ? Color(hex: 0x5C6570) : Theme.faint
    }

    var heading: Color {
        isLight ? Color(hex: 0x8A5B16) : Theme.goldLight
    }

    var controlAccent: Color {
        isLight ? Color(hex: 0x176B57) : Theme.gold
    }

    var buttonBackground: Color {
        isLight ? Color(hex: 0xD5A83D) : Theme.gold
    }

    var buttonText: Color {
        isLight ? Color(hex: 0x1E2B26) : Theme.night
    }

    var border: Color {
        isLight ? Color(hex: 0xD8D2C5) : Color.white.opacity(0.10)
    }

    var success: Color {
        isLight ? Color(hex: 0x16745A) : Theme.emerald
    }

    var verseMarker: Color {
        isLight ? Color(hex: 0x9A6716) : Theme.gold
    }

    var maddSix: Color { isLight ? Color(hex: 0x9A2F5D) : TajweedPalette.maddSix }
    var maddFive: Color { isLight ? Color(hex: 0xAE3C58) : TajweedPalette.maddFive }
    var maddTwoFourSix: Color { isLight ? Color(hex: 0x9D513B) : TajweedPalette.maddTwoFourSix }
    var maddTwo: Color { isLight ? Color(hex: 0x99601F) : TajweedPalette.maddTwo }
    var ikhfaGhunnah: Color { isLight ? Color(hex: 0x147255) : TajweedPalette.ikhfaGhunnah }
    var silent: Color { isLight ? Color(hex: 0x6D747A) : TajweedPalette.silent }
    var tafkhim: Color { isLight ? Color(hex: 0x216579) : TajweedPalette.tafkhim }
    var qalqalah: Color { isLight ? Color(hex: 0x116E9B) : TajweedPalette.qalqalah }
}