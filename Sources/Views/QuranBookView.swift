import SwiftUI
import PDFKit
import Combine
import UIKit

@MainActor
final class QuranBookStore: ObservableObject {
    @Published private(set) var verses: [QuranBookVerse] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadedSurahNumber: Int?
    @Published private(set) var loadedRiwaya: QuranBookRiwaya?
    @Published private(set) var pdfURL: URL?
    @Published private(set) var initialPDFPage: Int?

    private var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    func load(surahNumber: Int, riwaya: QuranBookRiwaya) {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        verses = []
        pdfURL = nil
        initialPDFPage = nil

        loadTask = Task { [weak self] in
            do {
                let document = try await QuranBookService.load(
                    surahNumber: surahNumber,
                    riwaya: riwaya
                )
                try Task.checkCancellation()
                self?.verses = document.verses
                self?.pdfURL = document.pdfURL
                self?.initialPDFPage = document.initialPDFPage
                self?.loadedSurahNumber = surahNumber
                self?.loadedRiwaya = riwaya
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
    @AppStorage("tilawa.book.riwaya") private var selectedRiwayaRaw = QuranBookRiwaya.hafs.rawValue

    private var selectedRiwaya: QuranBookRiwaya {
        QuranBookRiwaya(rawValue: selectedRiwayaRaw) ?? .hafs
    }

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
                        } else if let pdfURL = book.pdfURL {
                            QuranPDFReader(
                                url: pdfURL,
                                initialPage: book.initialPDFPage ?? 1
                            )
                            .frame(minHeight: 680)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else if book.verses.isEmpty {
                            EmptyStateView(
                                icon: "book.closed",
                                title: "Choisis une sourate",
                                message: "Le texte vérifié de la sourate apparaîtra ici."
                            )
                        } else {
                            if selectedRiwaya.hasVerifiedTajweedMarkup {
                                TajweedLegend()
                                    .padding(.top, 2)
                            }

                            ForEach(book.verses) { verse in
                                QuranVerseCard(
                                    verse: verse,
                                    riwaya: selectedRiwaya
                                )
                                .id(verse.id)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .onChange(of: book.verses.count) { _, _ in
                    guard let first = book.verses.first else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        scrollProxy.scrollTo(first.id, anchor: .top)
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
        .onChange(of: selectedRiwayaRaw) { _, _ in
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
                    Text("Le Coran · \(selectedRiwaya.shortTitle)")
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

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(QuranBookRiwaya.allCases) { riwaya in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedRiwayaRaw = riwaya.rawValue
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: riwaya.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(riwaya.shortTitle)
                                    .font(Theme.ui(11, .semibold))
                            }
                            .foregroundStyle(selectedRiwaya == riwaya ? Theme.night : Theme.muted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background {
                                if selectedRiwaya == riwaya {
                                    Capsule().fill(Theme.goldSheen)
                                } else {
                                    Capsule()
                                        .fill(Color.white.opacity(0.055))
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                                        )
                                }
                            }
                        }
                        .buttonStyle(PressScale(scale: 0.97))
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var sourceNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: selectedRiwaya.hasVerifiedTajweedMarkup
                  ? "checkmark.seal.fill"
                  : "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selectedRiwaya.hasVerifiedTajweedMarkup ? Theme.emerald : Theme.gold)
            Text(selectedRiwaya.sourceDescription)
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
        guard catalog.surah(selectedSurahNumber) != nil else { return }
        book.load(surahNumber: selectedSurahNumber, riwaya: selectedRiwaya)
    }
}

private struct QuranVerseCard: View {
    let verse: QuranBookVerse
    let riwaya: QuranBookRiwaya

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Text(verse.verseKey)
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.gold.opacity(0.7))
                Spacer()
                Text("\(verse.verseNumber)")
                    .font(Theme.mono(10, .semibold))
                    .foregroundStyle(Theme.night)
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(Theme.goldSheen))
            }

            if riwaya.hasVerifiedTajweedMarkup, let tajweedText = verse.tajweedText {
                TajweedText(rawValue: tajweedText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text(verse.plainText)
                    .font(Theme.arabic(23, .regular))
                    .foregroundStyle(Theme.ivory)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct TajweedText: View {
    let rawValue: String

    var body: some View {
        buildText(from: rawValue)
            .font(Theme.arabic(23, .regular))
            .lineSpacing(12)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func buildText(from raw: String) -> Text {
        let pattern = #"<tajweed class=([^>]+)>(.*?)</tajweed>|<span class=end>(.*?)</span>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return Text(verbatim: raw).foregroundStyle(Theme.ivory)
        }

        let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let matches = regex.matches(in: raw, options: [], range: nsRange)
        var result = Text("")
        var cursor = raw.startIndex

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: raw) else { continue }
            if cursor < fullRange.lowerBound {
                result = result + Text(verbatim: String(raw[cursor..<fullRange.lowerBound]))
                    .foregroundStyle(Theme.ivory)
            }

            let className = match.range(at: 1).location == NSNotFound
                ? "end"
                : (Range(match.range(at: 1), in: raw).map { String(raw[$0]) } ?? "")
            let contentRange = match.range(at: 2).location == NSNotFound
                ? match.range(at: 3)
                : match.range(at: 2)
            let content = Range(contentRange, in: raw).map { String(raw[$0]) } ?? ""

            result = result + Text(verbatim: content)
                .foregroundStyle(color(for: className))
            cursor = fullRange.upperBound
        }

        if cursor < raw.endIndex {
            result = result + Text(verbatim: String(raw[cursor...]))
                .foregroundStyle(Theme.ivory)
        }
        return result
    }

    private func color(for className: String) -> Color {
        switch className {
        case "ham_wasl", "laam_shamsiyah":
            return Theme.ivory.opacity(0.72)
        case "madda_normal", "madda_permissible":
            return Color(hex: 0x63D8A6)
        case "madda_obligatory":
            return Color(hex: 0x38BDF8)
        case "qalaqah":
            return Color(hex: 0xF26D78)
        case "idgham_ghunnah", "idgham_shafawi":
            return Color(hex: 0xC084FC)
        case "ikhfa", "ikhfa_shafawi":
            return Color(hex: 0xF5B86A)
        case "iqlab":
            return Color(hex: 0xFB8C60)
        case "idgham":
            return Color(hex: 0x4DD4C0)
        case "ghunnah":
            return Color(hex: 0x60A5FA)
        case "end":
            return Theme.gold
        default:
            return Theme.ivory
        }
    }
}

private struct TajweedLegend: View {
    private struct LegendItem: Identifiable {
        let id: String
        let title: String
        let color: Color
    }

    private let items: [LegendItem] = [
        LegendItem(id: "madd", title: "Madd", color: Color(hex: 0x63D8A6)),
        LegendItem(id: "qalqalah", title: "Qalqalah", color: Color(hex: 0xF26D78)),
        LegendItem(id: "idgham", title: "Idgham", color: Color(hex: 0xC084FC)),
        LegendItem(id: "ikhfa", title: "Ikhfa / Iqlab", color: Color(hex: 0xF5B86A))
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

private struct QuranPDFReader: UIViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }
        let index = max(0, min(initialPage - 1, document.pageCount - 1))
        guard let page = document.page(at: index) else { return }
        DispatchQueue.main.async {
            pdfView.go(to: page)
        }
    }
}