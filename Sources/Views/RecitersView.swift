import SwiftUI

struct RecitersView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager

    @State private var query = ""
    @State private var filter: ReciterFilter = .all
    @AppStorage("tilawa.selectedRiwaya") private var selectedRiwayaRaw = Riwaya.all.rawValue

    private var selectedRiwaya: Riwaya {
        Riwaya(rawValue: selectedRiwayaRaw) ?? .all
    }

    private var results: [Reciter] {
        let base = catalog.allReciters.filter { reciter in
            selectedRiwaya == .all
                || reciter.versions.contains { $0.riwaya == selectedRiwaya }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let filtered = base.filter { r in
            switch filter {
            case .all:        return true
            case .favorites:  return catalog.isFavorite(r.id)
            case .complete:   return !r.completeVersions.isEmpty
            case .downloaded: return r.versions.contains { downloads.downloadedCount(recitationId: $0.id) > 0 }
            }
        }

        guard !trimmed.isEmpty else { return filtered }
        let needle = Self.fold(trimmed)
        return filtered.filter {
            Self.fold($0.name).contains(needle)
                || $0.nameVariants.contains { Self.fold($0).contains(needle) }
                || $0.nameAr.contains(trimmed)
        }
    }

    /// Regroupement alphabétique, actif seulement en navigation libre :
    /// sur une recherche, la pertinence prime sur l'ordre.
    /// Type nommé plutôt qu'un tuple — Swift n'autorise pas de key path
    /// vers un élément de tuple, donc `ForEach(…, id: \.0)` ne compilerait pas.
    private struct LetterGroup: Identifiable {
        let id: String
        let reciters: [Reciter]
    }

    private var grouped: [LetterGroup] {
        Dictionary(grouping: results) { r -> String in
            r.custom ? "Mes sources" : String(r.name.prefix(1)).uppercased()
        }
        .sorted { a, b in
            if a.key == "Mes sources" { return true }
            if b.key == "Mes sources" { return false }
            return a.key < b.key
        }
        .map { LetterGroup(id: $0.key, reciters: $0.value) }
    }

    private var showGroups: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty && results.count > 12
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                            // Ancre stable utilisée par le bouton de retour en haut.
                            Color.clear
                                .frame(height: 1)
                                .id("recitersTop")

                            header

                            if catalog.isLoadingCatalog {
                                ProgressView("Chargement du catalogue…")
                                    .tint(Theme.gold)
                                    .foregroundStyle(Theme.faint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 60)
                            } else if results.isEmpty {
                                EmptyStateView(
                                    icon: "magnifyingglass",
                                    title: emptyTitle,
                                    message: emptyMessage
                                )
                            } else if showGroups {
                                ForEach(grouped) { group in
                                    Section {
                                        ForEach(group.reciters) { ReciterRow(reciter: $0) }
                                    } header: {
                                        letterHeader(group.id, count: group.reciters.count)
                                    }
                                }
                            } else {
                                ForEach(results) { ReciterRow(reciter: $0) }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.hidden)
                    .background(Color.clear)

                    // Toujours visible : l'utilisateur peut revenir en haut
                    // même après un petit défilement, sans seuil ni détection
                    // de géométrie fragile.
                    Button {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            scrollProxy.scrollTo("recitersTop", anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.night)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Theme.goldSheen.opacity(0.72))
                                    .background(.ultraThinMaterial, in: Circle())
                            )
                            .overlay(
                                Circle()
                                    .stroke(Theme.ivory.opacity(0.42), lineWidth: 1)
                            )
                            .shadow(color: Theme.night.opacity(0.5), radius: 12, y: 5)
                    }
                    .buttonStyle(PressScale(scale: 0.90))
                    .padding(.trailing, 18)
                    // La barre d'onglets est ajoutée par RootView via un
                    // safeAreaInset. Ce décalage place le bouton juste
                    // au-dessus de cette barre, sans passer dessous.
                    .padding(.bottom, 82)
                    .zIndex(10)
                    .accessibilityLabel("Remonter en haut")
                    .accessibilityHint("Retourne au début de la liste des récitateurs")
                }
                .navigationBarHidden(true)
            }
        }
    }

    // MARK: Sous-vues

    private var header: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tilawa")
                        .font(Theme.display(28, .bold))
                        .foregroundStyle(Theme.goldSheen)
                    Text(headerSummary)
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Text("تلاوة")
                    .font(Theme.arabic(30, .semibold))
                    .foregroundStyle(Theme.ivory.opacity(0.9))
            }
            .padding(.top, 8)

            OrnamentDivider()

            SearchField(text: $query)

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(ReciterFilter.allCases) { f in
                        FilterChip(title: f.title, icon: f.icon, selected: filter == f) {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    riwayaChip(.all)
                    ForEach(catalog.availableRiwayas) { riwaya in
                        riwayaChip(riwaya)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.bottom, 4)
    }

    private func riwayaChip(_ riwaya: Riwaya) -> some View {
        let selected = selectedRiwaya == riwaya
        let count = riwaya == .all
            ? catalog.totalVersions
            : catalog.riwayaCounts[riwaya, default: 0]

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRiwayaRaw = riwaya.rawValue
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: riwaya.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(riwaya.shortTitle)
                    .font(Theme.ui(10.5, .semibold))
                Text("\(count)")
                    .font(Theme.mono(9, .medium))
                    .opacity(0.72)
            }
            .foregroundStyle(selected ? Theme.night : Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule().fill(Theme.goldSheen)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.055))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
                }
            }
        }
        .buttonStyle(PressScale(scale: 0.97))
    }

    private var headerSummary: String {
        let count = results.count
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(count) résultat\(count > 1 ? "s" : "")"
        }
        if filter != .all {
            return "\(count) récitant\(count > 1 ? "s" : "") · \(filter.title)"
        }
        if selectedRiwaya != .all {
            return "\(count) récitant\(count > 1 ? "s" : "") · \(selectedRiwaya.title)"
        }
        return "\(catalog.allReciters.count) récitant\(catalog.allReciters.count > 1 ? "s" : "") · \(catalog.totalVersions) versions"
    }

    private var emptyTitle: String {
        switch filter {
        case .favorites: return "Aucun favori"
        case .downloaded: return "Aucun contenu hors connexion"
        default: return "Aucun résultat"
        }
    }

    private var emptyMessage: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Essaie un autre nom ou efface la recherche pour voir tout le catalogue."
        }
        switch filter {
        case .favorites:
            return "Appuie sur l'étoile d'un récitateur pour le retrouver ici."
        case .downloaded:
            return "Ouvre un récitateur, choisis une sourate et télécharge-la pour l'écouter sans réseau."
        case .complete:
            return "Aucun récitateur ne propose actuellement les 114 sourates."
        case .all:
            return "Le catalogue ne contient aucun récitateur pour le moment."
        }
    }

    private func letterHeader(_ letter: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(Theme.display(12.5, .bold))
                .foregroundStyle(Theme.gold)
            Rectangle()
                .fill(LinearGradient(colors: [Theme.gold.opacity(0.28), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("\(count)")
                .font(Theme.mono(10, .medium))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Comparaison insensible à la casse et aux diacritiques (« Sudais » trouve « Sudaïs »).
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

enum ReciterFilter: Int, CaseIterable, Identifiable {
    case all, favorites, complete, downloaded

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all:        return "Tous"
        case .favorites:  return "Favoris"
        case .complete:   return "Mushaf complet"
        case .downloaded: return "Hors ligne"
        }
    }
    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2"
        case .favorites:  return "star.fill"
        case .complete:   return "checkmark.seal"
        case .downloaded: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Ligne de récitateur

struct ReciterRow: View {
    let reciter: Reciter
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage("tilawa.selectedRiwaya") private var selectedRiwayaRaw = Riwaya.all.rawValue

    private var selectedRiwaya: Riwaya {
        Riwaya(rawValue: selectedRiwayaRaw) ?? .all
    }

    private var offlineCount: Int {
        reciter.versions.reduce(0) { $0 + downloads.downloadedCount(recitationId: $1.id) }
    }

    var body: some View {
        NavigationLink {
            ReciterDetailView(reciter: reciter, initialRiwaya: selectedRiwaya)
        } label: {
            HStack(spacing: 12) {
                Monogram(reciter: reciter, side: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reciter.name)
                        .font(Theme.ui(15, .semibold))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if reciter.hasArabicName {
                        Text(reciter.nameAr)
                            .font(Theme.arabic(13.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 5) {
                            if reciter.hasNameVariants {
                                Chip(text: "\(reciter.nameVariants.count) orthographes", icon: "textformat")
                            }
                            if reciter.custom {
                                Chip(text: "Ma source", icon: "link", tint: Theme.gold)
                            }
                            if reciter.versions.count > 1 {
                                Chip(text: "\(reciter.versions.count) versions", icon: "square.stack.3d.up")
                            }
                            let riwayas = Array(Set(reciter.versions.map(\.riwaya)))
                                .filter { $0 != .unspecified && $0 != .all }
                                .sorted { $0.shortTitle < $1.shortTitle }
                            if !riwayas.isEmpty {
                                Chip(
                                    text: riwayas.count == 1
                                        ? riwayas[0].shortTitle
                                        : "\(riwayas.count) riwayat",
                                    icon: "book.closed"
                                )
                            }
                            if !reciter.completeVersions.isEmpty {
                                Chip(text: "114 sourates", icon: "checkmark.seal.fill", tint: Theme.emerald)
                            }
                            if offlineCount > 0 {
                                Chip(text: "\(offlineCount) hors ligne",
                                     icon: "arrow.down.circle.fill", tint: Theme.teal)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                HStack(spacing: 2) {
                    Button {
                        catalog.toggleFavorite(reciter.id)
                    } label: {
                        Image(systemName: catalog.isFavorite(reciter.id) ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(catalog.isFavorite(reciter.id) ? Theme.gold : Theme.faint)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.faint.opacity(0.7))
                        .frame(width: 14)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .glass(radius: Theme.radiusCard, elevation: 0.7)
        }
        .buttonStyle(PressScale(scale: 0.985))
    }
}
