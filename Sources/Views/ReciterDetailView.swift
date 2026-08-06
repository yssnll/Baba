import SwiftUI

struct ReciterDetailView: View {
    let reciter: Reciter

    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var versionIndex = 0
    @State private var query = ""
    @State private var confirmRemoveAll = false

    private var version: Recitation? {
        guard reciter.versions.indices.contains(versionIndex) else { return reciter.versions.first }
        return reciter.versions[versionIndex]
    }

    /// Sourates réellement proposées par la version choisie.
    private var surahs: [Surah] {
        guard let version else { return [] }
        let available = version.availableSet
        return catalog.surahs.filter { available.contains($0.number) }
    }

    private var visibleSurahs: [Surah] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return surahs }
        if let n = Int(trimmed) { return surahs.filter { $0.number == n } }
        let needle = RecitersView.fold(trimmed)
        return surahs.filter {
            RecitersView.fold($0.nameFr).contains(needle)
                || RecitersView.fold($0.nameTranslit).contains(needle)
                || $0.nameAr.contains(trimmed)
        }
    }

    private var offlineCount: Int {
        guard let version else { return 0 }
        return downloads.downloadedCount(recitationId: version.id)
    }

    /// File complète : permet au lecteur d'enchaîner tout le mushaf.
    private var queue: [Track] {
        guard let version else { return [] }
        return surahs.map { track(for: $0, version: version) }
    }

    private func track(for surah: Surah, version: Recitation) -> Track {
        Track(reciterId: reciter.id, reciterName: reciter.name,
              reciterNameAr: reciter.nameAr, recitation: version, surah: surah)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                header
                if reciter.versions.count > 1 { versionPicker }
                actionBar
                    .padding(.bottom, 2)

                SearchField(text: $query, placeholder: "Sourate ou numéro…")
                    .padding(.bottom, 2)

                if let version {
                    if visibleSurahs.isEmpty {
                        EmptyStateView(icon: "text.magnifyingglass",
                                       title: "Aucune sourate",
                                       message: "Aucune sourate ne correspond à « \(query) ».")
                    } else {
                        ForEach(visibleSurahs) { surah in
                            SurahRow(track: track(for: surah, version: version), queue: queue)
                        }
                    }
                } else {
                    EmptyStateView(icon: "exclamationmark.triangle",
                                   title: "Aucune version",
                                   message: "Ce récitateur n'expose aucune récitation utilisable.")
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(LiquidBackdrop().opacity(0.9))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Supprimer les fichiers hors ligne de cette version ?",
                            isPresented: $confirmRemoveAll, titleVisibility: .visible) {
            Button("Supprimer \(offlineCount) fichier\(offlineCount > 1 ? "s" : "")", role: .destructive) {
                if let version { downloads.removeAll(recitationId: version.id) }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                        Text("Retour").font(Theme.ui(13, .medium))
                    }
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    catalog.toggleFavorite(reciter.id)
                } label: {
                    Image(systemName: catalog.isFavorite(reciter.id) ? "star.fill" : "star")
                        .font(.system(size: 15))
                        .foregroundStyle(catalog.isFavorite(reciter.id) ? Theme.gold : Theme.faint)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)

            Monogram(reciter: reciter, side: 74)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 7)

            VStack(spacing: 4) {
                Text(reciter.name)
                    .font(Theme.display(21, .bold))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.center)

                if reciter.hasArabicName {
                    Text(reciter.nameAr)
                        .font(Theme.arabic(17))
                        .foregroundStyle(Theme.gold.opacity(0.85))
                }
            }

            HStack(spacing: 6) {
                Chip(text: "\(surahs.count) sourates", icon: "book.closed")
                if let version {
                    Chip(text: version.providerLabel, icon: "antenna.radiowaves.left.and.right")
                }
                if offlineCount > 0 {
                    Chip(text: "\(offlineCount) hors ligne",
                         icon: "arrow.down.circle.fill", tint: Theme.emerald)
                }
            }

            OrnamentDivider().padding(.top, 2)
        }
    }

    // MARK: Sélecteur de version

    private var versionPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader(title: "Version", subtitle: "Riwaya et source audio")

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Array(reciter.versions.enumerated()), id: \.element.id) { idx, v in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { versionIndex = idx }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(v.shortLabel)
                                    .font(Theme.ui(12.5, .semibold))
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text("\(v.surahList.count) sourates")
                                        .font(Theme.mono(9.5, .medium))
                                    Text("·").font(Theme.mono(9.5))
                                    Text(v.providerLabel)
                                        .font(Theme.ui(9.5, .medium))
                                }
                                .foregroundStyle(versionIndex == idx ? Theme.night.opacity(0.7) : Theme.faint)
                            }
                            .foregroundStyle(versionIndex == idx ? Theme.night : Theme.ivory.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(minWidth: 130, alignment: .leading)
                            .background {
                                if versionIndex == idx {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Theme.goldSheen)
                                } else {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
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

    // MARK: Actions groupées

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                guard let first = queue.first else { return }
                player.play(first, in: queue)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                    Text("Écouter").font(Theme.ui(13.5, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.accent)
                )
                .shadow(color: Theme.emerald.opacity(0.32), radius: 12, y: 5)
            }
            .buttonStyle(PressScale())
            .disabled(queue.isEmpty)

            Button {
                guard let version else { return }
                downloads.enqueueAll(reciter: reciter, recitation: version, surahs: surahs)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 12, weight: .bold))
                    Text("Tout").font(Theme.ui(13.5, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .glass(radius: 15, elevation: 0.6)
            }
            .buttonStyle(PressScale())
            .disabled(version == nil || offlineCount >= surahs.count)

            if offlineCount > 0 {
                Button {
                    confirmRemoveAll = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 44)
                        .padding(.vertical, 11)
                        .glass(radius: 15, elevation: 0.6)
                }
                .buttonStyle(PressScale())
            }
        }
    }
}

// MARK: - Ligne de sourate

struct SurahRow: View {
    let track: Track
    let queue: [Track]

    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerService

    private var isCurrent: Bool { player.current?.id == track.id }
    private var state: DownloadState { downloads.state(for: track) }

    var body: some View {
        HStack(spacing: 11) {
            Button {
                player.toggle(track, in: queue)
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        SurahMedallion(number: track.surah.number, active: isCurrent, side: 40)
                        if isCurrent && player.isPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.ivory)
                                .symbolEffect(.variableColor.iterative, options: .repeating)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.surah.nameFr)
                            .font(Theme.ui(14.5, .semibold))
                            .foregroundStyle(isCurrent ? Theme.emerald : Theme.ivory)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(track.surah.nameTranslit)
                                .font(Theme.ui(11, .regular))
                                .foregroundStyle(Theme.faint)
                            Text("·").foregroundStyle(Theme.faint)
                            Text("\(track.surah.verses) versets")
                                .font(Theme.mono(10, .regular))
                                .foregroundStyle(Theme.faint)
                        }
                        .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text(track.surah.nameAr)
                        .font(Theme.arabic(16))
                        .foregroundStyle(Theme.gold.opacity(0.82))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DownloadButton(state: state, side: 30) {
                switch state {
                case .idle, .failed:
                    downloads.enqueue(track)
                case .waiting, .downloading:
                    downloads.cancel(track)
                case .done:
                    downloads.remove(recitationId: track.recitation.id, surah: track.surah.number)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .glass(radius: 17, elevation: isCurrent ? 0.9 : 0.5)
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Theme.emerald.opacity(0.55), lineWidth: 1)
            }
        }
    }
}
