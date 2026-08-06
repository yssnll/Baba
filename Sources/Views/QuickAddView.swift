import SwiftUI

/// Ajout en un appui.
///
/// Liste les récitateurs du catalogue : un appui sur le nom résout la source
/// tout seul (mushaf complet privilégié), met les 114 sourates en file et rend
/// le tout disponible hors ligne. Aucune adresse à saisir.
struct QuickAddView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var onlyComplete = true
    @State private var justTapped: String?

    private var results: [Reciter] {
        let base = catalog.allReciters.filter { r in
            guard r.preferredVersion != nil else { return false }
            return onlyComplete ? !r.completeVersions.isEmpty : true
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return base }
        let needle = RecitersView.fold(trimmed)
        return base.filter {
            RecitersView.fold($0.name).contains(needle) || $0.nameAr.contains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            LiquidBackdrop(intensity: 1.1)

            VStack(spacing: 0) {
                header

                if results.isEmpty {
                    EmptyStateView(icon: "magnifyingglass",
                                   title: "Aucun récitateur",
                                   message: "Essaie un autre nom, ou décoche « mushaf complet ».")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(results) { reciter in
                                QuickAddRow(reciter: reciter, flashing: justTapped == reciter.id) {
                                    add(reciter)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .presentationBackground(.clear)
    }

    private var header: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ajouter en un appui")
                        .font(Theme.display(20, .bold))
                        .foregroundStyle(Theme.goldSheen)
                    Text("Un appui = source détectée, tout téléchargé, prêt hors ligne")
                        .font(Theme.ui(11, .regular))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 32, height: 32)
                        .glass(radius: 11, elevation: 0.5)
                }
                .buttonStyle(PressScale())
            }
            .padding(.top, 14)

            SearchField(text: $query)

            HStack(spacing: 7) {
                FilterChip(title: "Mushaf complet", icon: "checkmark.seal",
                           selected: onlyComplete) {
                    withAnimation(.easeInOut(duration: 0.2)) { onlyComplete.toggle() }
                }
                Spacer()
                Text("\(results.count)")
                    .font(Theme.mono(11, .medium))
                    .foregroundStyle(Theme.gold.opacity(0.75))
            }

            OrnamentDivider()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 9)
    }

    private func add(_ reciter: Reciter) {
        guard let version = reciter.preferredVersion else { return }
        downloads.enqueueAll(reciter: reciter, recitation: version, surahs: catalog.surahs)

        // Retour visuel bref : confirme que l'appui a été pris en compte,
        // avant que les premiers pourcentages n'apparaissent.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            justTapped = reciter.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if justTapped == reciter.id {
                withAnimation(.easeOut(duration: 0.3)) { justTapped = nil }
            }
        }
    }
}

// MARK: - Ligne

private struct QuickAddRow: View {
    let reciter: Reciter
    let flashing: Bool
    let action: () -> Void

    @EnvironmentObject private var downloads: DownloadManager
    @State private var confirmRemove = false

    private var version: Recitation? { reciter.preferredVersion }

    private var total: Int { version?.surahList.count ?? 0 }
    private var done: Int { version.map { downloads.downloadedCount(recitationId: $0.id) } ?? 0 }

    /// Transferts encore en vol pour cette version.
    private var active: Int {
        guard let version else { return 0 }
        let prefix = version.id + "#"
        return downloads.states.filter { $0.key.hasPrefix(prefix) && $0.value.isActive }.count
    }

    private var isComplete: Bool { total > 0 && done >= total }
    private var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        HStack(spacing: 11) {
            Monogram(reciter: reciter, side: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(reciter.name)
                    .font(Theme.ui(14.5, .semibold))
                    .foregroundStyle(isComplete ? Theme.emerald : Theme.ivory)
                    .lineLimit(1)

                if reciter.hasArabicName {
                    Text(reciter.nameAr)
                        .font(Theme.arabic(13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    if isComplete {
                        Chip(text: "Prêt hors ligne", icon: "checkmark.circle.fill", tint: Theme.emerald)
                    } else if active > 0 {
                        Chip(text: "\(done)/\(total) · \(active) en cours",
                             icon: "arrow.down.circle", tint: Theme.teal)
                    } else if done > 0 {
                        Chip(text: "\(done)/\(total)", icon: "arrow.down.circle", tint: Theme.teal)
                    } else {
                        Chip(text: "\(total) sourates", icon: "book.closed")
                    }
                    if let version, version.isComplete {
                        Chip(text: "114", icon: "checkmark.seal.fill", tint: Theme.gold)
                    }
                }
            }

            Spacer(minLength: 2)

            // Un seul geste : télécharger, ou supprimer si déjà complet.
            Button {
                if isComplete { confirmRemove = true } else { action() }
            } label: {
                ZStack {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Theme.emerald)
                    } else if done > 0 || active > 0 {
                        ZStack {
                            ProgressRing(fraction: fraction, side: 30)
                            Text("\(Int(fraction * 100))")
                                .font(Theme.mono(8.5, .bold))
                                .foregroundStyle(Theme.ivory)
                        }
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(Theme.gold)
                    }
                }
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .glass(radius: Theme.radiusCard, elevation: flashing ? 1.1 : 0.6)
        .overlay {
            if flashing {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .stroke(Theme.gold, lineWidth: 1.4)
            } else if isComplete {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .stroke(Theme.emerald.opacity(0.4), lineWidth: 0.9)
            }
        }
        .scaleEffect(flashing ? 1.015 : 1)
        // Toute la ligne est cliquable : « il suffit de cliquer sur le nom ».
        .contentShape(Rectangle())
        .onTapGesture {
            if !isComplete { action() }
        }
        .confirmationDialog("Supprimer les \(done) sourates de \(reciter.name) ?",
                            isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let version { downloads.removeAll(recitationId: version.id) }
            }
            Button("Annuler", role: .cancel) {}
        }
    }
}
