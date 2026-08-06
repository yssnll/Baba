import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var showAddReciter = false
    @State private var showQuickAdd = false
    @State private var confirmWipe = false

    private var lastRefreshText: String {
        guard let date = catalog.lastRefresh else { return "Jamais synchronisé" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .full
        return "Synchronisé " + f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                header
                appearanceCard
                catalogCard
                customSourcesCard
                networkCard
                storageCard
                aboutCard
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showAddReciter) {
            AddReciterView()
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView()
        }
        .confirmationDialog("Supprimer tout l'audio téléchargé ?",
                            isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Tout supprimer (\(Fmt.bytes(downloads.totalBytes)))", role: .destructive) {
                downloads.removeEverything()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: Sections

    private var appearanceCard: some View {
        card {
            SectionHeader(title: "Apparence",
                          subtitle: "Personnalise les couleurs de Tilawa")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(AppearanceSettings.Preset.allCases) { preset in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                appearance.applyPreset(preset)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(preset.title)
                                    .font(Theme.ui(10.5, .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(appearance.preset == preset
                                             ? appearance.background
                                             : appearance.text)
                            .frame(width: 105, height: 58)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(presetColor(for: preset))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(appearance.preset == preset
                                            ? appearance.gold
                                            : appearance.text.opacity(0.12),
                                            lineWidth: appearance.preset == preset ? 1.3 : 0.8)
                            }
                        }
                        .buttonStyle(PressScale(scale: 0.97))
                        .disabled(preset == .custom)
                        .opacity(preset == .custom && appearance.preset != .custom ? 0.72 : 1)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            OrnamentDivider()

            Text("Couleurs principales")
                .font(Theme.ui(11.5, .semibold))
                .foregroundStyle(appearance.muted)

            appearanceColorRow("Fond", color: appearance.background) {
                appearance.setBackground($0)
            }
            appearanceColorRow("Surfaces", color: appearance.surface) {
                appearance.setSurface($0)
            }
            appearanceColorRow("Accent", color: appearance.accent) {
                appearance.setAccent($0)
            }
            appearanceColorRow("Doré", color: appearance.gold) {
                appearance.setGold($0)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(appearance.accent)
                    .frame(width: 9, height: 9)
                Text(appearance.preset == .custom
                     ? "Palette personnalisée"
                     : appearance.preset.title)
                    .font(Theme.ui(10.5, .medium))
                    .foregroundStyle(appearance.muted)
                Spacer()
                Text("Enregistrée automatiquement")
                    .font(Theme.ui(9.5, .regular))
                    .foregroundStyle(appearance.muted)
            }
        }
    }

    private func presetColor(for preset: AppearanceSettings.Preset) -> Color {
        switch preset {
        case .nocturne: return Color(red: 0.18, green: 0.13, blue: 0.24)
        case .emerald: return Color(red: 0.10, green: 0.31, blue: 0.25)
        case .sapphire: return Color(red: 0.11, green: 0.28, blue: 0.48)
        case .ruby: return Color(red: 0.43, green: 0.13, blue: 0.20)
        case .ivory: return Color(red: 0.96, green: 0.91, blue: 0.82)
        case .custom: return appearance.surface
        }
    }

    private func appearanceColorRow(
        _ title: String,
        color: Color,
        onChange: @escaping (Color) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.ui(12.5, .medium))
                .foregroundStyle(appearance.text)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { color },
                set: { onChange($0) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Réglages")
                    .font(Theme.display(26, .bold))
                    .foregroundStyle(Theme.goldSheen)
                Spacer()
            }
            .padding(.top, 8)
            OrnamentDivider()
        }
    }

    private var catalogCard: some View {
        card {
            SectionHeader(title: "Catalogue",
                          subtitle: "\(catalog.allReciters.count) récitateurs · \(catalog.totalVersions) versions")

            Text(lastRefreshText)
                .font(Theme.ui(11.5, .regular))
                .foregroundStyle(Theme.faint)

            if let message = catalog.refreshMessage {
                Text(message)
                    .font(Theme.ui(11.5, .medium))
                    .foregroundStyle(Theme.emerald)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await catalog.refresh() }
            } label: {
                HStack(spacing: 7) {
                    if catalog.isRefreshing {
                        ProgressView().scaleEffect(0.7).tint(Theme.ivory)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(catalog.isRefreshing ? "Synchronisation…" : "Synchroniser le catalogue")
                        .font(Theme.ui(13, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent)
                )
            }
            .buttonStyle(PressScale())
            .disabled(catalog.isRefreshing)

            Text("Récupère la liste à jour depuis MP3Quran et QuranicAudio, puis la met en cache pour un usage hors ligne.")
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var customSourcesCard: some View {
        card {
            SectionHeader(title: "Sources",
                           subtitle: "\(catalog.custom.count) source\(catalog.custom.count > 1 ? "s" : "") personnalisée\(catalog.custom.count > 1 ? "s" : "")")

            // Voie principale : aucune adresse à saisir.
            Button {
                showQuickAdd = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 15, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ajouter en un appui")
                            .font(Theme.ui(13.5, .semibold))
                        Text("Source détectée, tout téléchargé, prêt hors ligne")
                            .font(Theme.ui(10, .regular))
                            .opacity(0.75)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.6)
                }
                .foregroundStyle(Theme.night)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.goldSheen)
                )
            }
            .buttonStyle(PressScale())

            OrnamentDivider()

            Text("Récitateur absent du catalogue ?")
                .font(Theme.ui(11.5, .semibold))
                .foregroundStyle(Theme.muted)

            if catalog.custom.isEmpty {
                Text("Aucune source personnalisée.")
                    .font(Theme.ui(11.5, .regular))
                    .foregroundStyle(Theme.faint)
            } else {
                ForEach(catalog.custom) { reciter in
                    HStack(spacing: 10) {
                        Monogram(reciter: reciter, side: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reciter.name)
                                .font(Theme.ui(13, .semibold))
                                .foregroundStyle(Theme.ivory)
                                .lineLimit(1)
                            Text(reciter.versions.first?.urlTemplate ?? "")
                                .font(Theme.mono(9, .regular))
                                .foregroundStyle(Theme.faint)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            catalog.removeCustomReciter(id: reciter.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
            }

            Button {
                showAddReciter = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "link").font(.system(size: 12, weight: .bold))
                    Text("Ajouter par adresse").font(Theme.ui(13, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .glass(radius: 14, elevation: 0.55)
            }
            .buttonStyle(PressScale())
        }
    }

    private var networkCard: some View {
        card {
            SectionHeader(title: "Téléchargements",
                          subtitle: "Contrôle l'utilisation de ton forfait")

            Toggle(isOn: Binding(
                get: { downloads.wifiOnly },
                set: { downloads.wifiOnly = $0 }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Télécharger en Wi-Fi uniquement")
                        .font(Theme.ui(13, .medium))
                        .foregroundStyle(Theme.ivory)
                    Text("Préserve ton forfait mobile")
                        .font(Theme.ui(10.5, .regular))
                        .foregroundStyle(Theme.faint)
                }
            }
            .tint(Theme.emerald)

            if downloads.activeCount > 0 {
                Text("\(downloads.activeCount) téléchargement\(downloads.activeCount > 1 ? "s" : "") en cours")
                    .font(Theme.ui(11, .medium))
                    .foregroundStyle(Theme.teal)
            }

            Text("La lecture en streaming utilise la connexion disponible. Les sourates téléchargées restent accessibles sans réseau.")
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var storageCard: some View {
        card {
            SectionHeader(title: "Stockage",
                          subtitle: Fmt.bytes(downloads.totalBytes) + " occupés")

            Text("Compte environ 200 à 400 Mo par mushaf complet. L'audio est exclu des sauvegardes iCloud : il reste retéléchargeable.")
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                confirmWipe = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "trash")
                    Text("Supprimer tout l'audio")
                }
                    .font(Theme.ui(13, .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .glass(radius: 14, elevation: 0.5)
            }
            .buttonStyle(PressScale())
            .disabled(downloads.totalBytes == 0)
            .opacity(downloads.totalBytes == 0 ? 0.4 : 1)
        }
    }

    private var aboutCard: some View {
        card {
            SectionHeader(title: "À propos")

            VStack(alignment: .leading, spacing: 7) {
                row("Version", "1.0.0")
                row("Sourates", "114 · métadonnées embarquées")
                row("Sources audio", "MP3Quran · QuranicAudio")
            }

            Text("Les enregistrements sont diffusés depuis les serveurs de MP3Quran.net et QuranicAudio.com. Tilawa ne redistribue aucun fichier : il pointe vers ces sources et met en cache ce que tu choisis d'écouter hors ligne. Merci de respecter leurs conditions d'usage et d'éviter les téléchargements massifs — ces serveurs vivent de dons.")
                .font(Theme.ui(10.5, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Utilitaires

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.ui(12, .regular))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(Theme.ui(12, .medium))
                .foregroundStyle(Theme.ivory)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: Theme.radiusCard, elevation: 0.7)
    }
}

// MARK: - Ajout d'une source

struct AddReciterView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameAr = ""
    @State private var template = ""
    @State private var label = ""
    @State private var error: String?

    var body: some View {
        ZStack {
            LiquidBackdrop(intensity: 1.1)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ajouter un récitateur")
                            .font(Theme.display(21, .bold))
                            .foregroundStyle(Theme.goldSheen)
                        Text("N'importe quel serveur qui expose un fichier par sourate.")
                            .font(Theme.ui(11.5, .regular))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.top, 6)

                    field("Nom", text: $name, placeholder: "Ex. Mishary Al-Afasy")
                    field("Nom en arabe (facultatif)", text: $nameAr, placeholder: "مشاري العفاسي")
                    field("Nom de la version (facultatif)", text: $label, placeholder: "Hafs · Murattal")

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Adresse de la source")
                            .font(Theme.ui(11.5, .semibold))
                            .foregroundStyle(Theme.muted)

                        TextEditor(text: $template)
                            .font(Theme.mono(11.5, .regular))
                            .foregroundStyle(Theme.ivory)
                            .scrollContentBackground(.hidden)
                            .frame(height: 66)
                            .padding(9)
                            .glass(radius: 13, elevation: 0.5)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Text("Colle soit le dossier (`https://serveur.net/dossier/`), soit un gabarit avec `{sss}` pour le numéro sur 3 chiffres — `{s}` pour le numéro brut.")
                            .font(Theme.ui(10, .regular))
                            .foregroundStyle(Theme.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error {
                        Text(error)
                            .font(Theme.ui(11.5, .medium))
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 9) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Annuler")
                                .font(Theme.ui(13, .semibold))
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .glass(radius: 14, elevation: 0.5)
                        }
                        .buttonStyle(PressScale())

                        Button {
                            if let message = catalog.addCustomReciter(
                                name: name, nameAr: nameAr,
                                template: template, versionLabel: label
                            ) {
                                error = message
                            } else {
                                dismiss()
                            }
                        } label: {
                            Text("Ajouter")
                                .font(Theme.ui(13, .semibold))
                                .foregroundStyle(Theme.ivory)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.accent)
                                )
                        }
                        .buttonStyle(PressScale())
                    }
                    .padding(.top, 4)

                    exampleCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .presentationBackground(.clear)
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exemples valides")
                .font(Theme.ui(11.5, .semibold))
                .foregroundStyle(Theme.gold)
            Text(verbatim: "https://server8.mp3quran.net/afs/")
                .font(Theme.mono(10, .regular))
                .foregroundStyle(Theme.muted)
            Text(verbatim: "https://download.quranicaudio.com/quran/mishaari_raashid_al_i3fasee/{sss}.mp3")
                .font(Theme.mono(10, .regular))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 15, elevation: 0.5)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(Theme.ui(11.5, .semibold))
                .foregroundStyle(Theme.muted)
            TextField(placeholder, text: text)
                .font(Theme.ui(14, .regular))
                .foregroundStyle(Theme.ivory)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .glass(radius: 13, elevation: 0.5)
        }
    }
}
