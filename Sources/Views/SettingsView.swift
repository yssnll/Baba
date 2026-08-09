import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var appearance = AppearanceSettings.shared

    @State private var showAddReciter = false
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
                widgetCard
                catalogCard
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
                          subtitle: "Choisis une palette")

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
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                Circle()
                    .fill(appearance.accent)
                    .frame(width: 9, height: 9)
                Text(appearance.preset.title)
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

            if let succeeded = catalog.refreshSucceeded {
                Label(
                    succeeded ? "Dernière synchronisation réussie" : "Dernière synchronisation échouée",
                    systemImage: succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(Theme.ui(10.5, .medium))
                .foregroundStyle(succeeded ? Theme.emerald : Theme.danger)
            }

            if let message = catalog.refreshMessage {
                Text(message)
                    .font(Theme.ui(11.5, .medium))
                    .foregroundStyle(catalog.refreshSucceeded == false ? Theme.danger : Theme.emerald)
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

            Button {
                showAddReciter = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .bold))
                    Text("Ajouter une source")
                        .font(Theme.ui(13, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .glass(radius: 14, elevation: 0.55)
            }
            .buttonStyle(PressScale())
        }
    }

    private var widgetCard: some View {
        card {
            SectionHeader(
                title: "Widget",
                subtitle: "État du partage avec l'écran d'accueil"
            )

            Label(
                player.widgetSyncIsAvailable
                    ? "Synchronisation disponible"
                    : "Synchronisation indisponible",
                systemImage: player.widgetSyncIsAvailable
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .font(Theme.ui(12, .semibold))
            .foregroundStyle(player.widgetSyncIsAvailable ? Theme.emerald : Theme.danger)

            Text(player.widgetSyncStatus)
                .font(Theme.mono(10, .regular))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                player.widgetSyncIsAvailable
                    ? "L'état de la piste et de la lecture est partagé avec TilawaWidget."
                    : "eSign a probablement retiré l'App Group. Signe l'app et TilawaWidget avec le même profil contenant group.app.tilawa."
            )
            .font(Theme.ui(10.5, .regular))
            .foregroundStyle(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                player.refreshWidgetSnapshot()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .bold))
                    Text("Tester la synchronisation")
                        .font(Theme.ui(13, .semibold))
                }
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(player.widgetSyncIsAvailable ? Theme.accent : Theme.muted.opacity(0.35))
                )
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
                row("Version", "3.4")
                row("Créé par", "Yssnll")
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
