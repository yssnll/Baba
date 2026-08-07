# Tilawa — تلاوة

Application iOS de récitation du Coran. Catalogue de **328 récitateurs**, **463 versions de lecture**, **114 sourates**, écoute **hors ligne** et ajout de **n'importe quelle source au monde**.

La version 3.4 améliore le lecteur plein écran, les états de chargement et d'erreur,
la visibilité des téléchargements et la lisibilité des écrans principaux.

Créé par **Yssnll**.

Interface SwiftUI : verre translucide animé, géométrie islamique vectorielle, palette nuit / émeraude / or.

La version actuelle propose aussi :

- des commandes Siri pour dire « Lis la Fatiha avec Yasser Al-Dossari dans Tilawa » ou « Mets Muaqly dans Tilawa » ;
- un widget d'écran d'accueil pour reprendre, mettre en pause et passer à la sourate suivante ;
- une sélection Siri de la sourate et du récitateur à partir du catalogue embarqué.

Pour les widgets, Siri et la lecture depuis l'écran verrouillé, l'application doit être signée avec un compte Apple configuré pour l'App Group `group.app.tilawa`.

---

## À lire avant tout : l'état réel du projet

Trois choses honnêtes, pour t'éviter une mauvaise surprise.

**1. Le code n'a pas été compilé.** Il a été écrit sous Linux, où aucun compilateur Swift n'est disponible. Ce qui **a** été vérifié :

| Vérification | Résultat |
|---|---|
| Équilibrage syntaxique des 15 fichiers Swift | ✅ tous corrects |
| Conformité des JSON aux modèles `Codable` | ✅ aucun champ manquant |
| Unicité des identifiants (récitateurs + versions) | ✅ garantie |
| Total des versets du catalogue | ✅ 6236 (compte canonique) |
| URLs audio générées par les gabarits | ✅ 7/7 testées → `200 audio/mpeg` |

La première compilation peut donc encore révéler des erreurs (un type, un argument). Elles sont normalement rapides à corriger : envoie-moi le log d'erreur de la CI et je les traite.

**2. L'IPA produite est non signée.** Aucun outil ne peut signer à ta place : la signature dépend de ton compte Apple et de ton appareil. La section *Installer* explique comment le faire gratuitement.

**3. Les récitations ne sont pas embarquées dans l'app.** C'est un choix, pas un oubli — voir *Le modèle hors ligne*.

---

## Compiler

### Option A — GitHub Actions (aucun Mac nécessaire) ⭐

1. Crée un dépôt GitHub et pousse **le contenu de ce dossier à la racine** (`project.yml` doit être à la racine du dépôt).
2. Onglet **Actions** → *Build IPA* → **Run workflow**.
3. À la fin (~5 min), récupère l'artefact `Tilawa-unsigned-ipa`.

Les runners macOS sont gratuits pour les dépôts publics.

### Option B — Sur un Mac

```bash
./build-ipa.sh          # installe XcodeGen si besoin, compile, produit l'IPA
```

Pour travailler dans Xcode :

```bash
brew install xcodegen
xcodegen generate
open Tilawa.xcodeproj
```

> Le fichier `.xcodeproj` n'est pas versionné : il est **généré** depuis `project.yml`. Après avoir ajouté un fichier source, relance `xcodegen generate`.

---

## Installer sur l'iPhone

L'IPA doit être signée avec **ton** identité. Les options, du plus simple au plus durable :

| Méthode | Coût | Validité | Remarque |
|---|---|---|---|
| **Sideloadly** | gratuit | **7 jours** | Le plus simple. Identifiant Apple ordinaire, PC ou Mac + câble. |
| **AltStore** | gratuit | 7 jours, **renouvelé automatiquement** | Se resigne tout seul si le PC est sur le même réseau. Le meilleur compromis. |
| Compte développeur Apple | 99 $/an | 1 an | Confortable, mais probablement disproportionné ici. |
| **TrollStore** | gratuit | permanent | Uniquement sur certaines versions d'iOS vulnérables. Vérifie la compatibilité de la tienne avant d'y compter. |

Avec un identifiant gratuit : **3 applications maximum** installées simultanément, et resignature tous les 7 jours (l'app cesse de s'ouvrir sinon — les fichiers téléchargés, eux, restent).

Le plus fluide en pratique : **AltStore**.

---

## Le modèle hors ligne

Tu voulais tout embarquer dans l'IPA. C'est impossible, et voici les chiffres :

- un mushaf complet en MP3 pèse **200 à 400 Mo** par récitateur ;
- 328 récitateurs ≈ **150 à 200 Go** ;
- le plafond Apple pour un bundle d'app est de **4 Go**.

Trois récitateurs suffiraient à faire échouer la compilation.

**Ce qui est fait à la place :**

- le **catalogue complet** (328 récitateurs, 463 versions, 114 sourates) est embarqué dans l'app en JSON → il s'affiche dès le premier lancement, même sans réseau ;
- tu télécharges **ce que tu veux, quand tu veux** : une sourate, ou tout un mushaf d'un seul geste ;
- une fois téléchargé, l'audio joue **sans aucun réseau** — avion, métro, partout ;
- la bascule fichier local / diffusion est automatique et invisible.

Les téléchargements passent par une session d'arrière-plan : ils continuent app fermée et reprennent au relancement.

---

## Ajouter n'importe quel récitateur

**Réglages → Mes sources → Ajouter un récitateur.**

Colle soit un dossier, soit un gabarit :

```
https://serveur.net/dossier/                    → complété en {sss}.mp3
https://serveur.net/dossier/{sss}.mp3           → {sss} = numéro sur 3 chiffres (001)
https://serveur.net/dossier/{s}.mp3             → {s}   = numéro brut (1)
```

Tes sources apparaissent en tête de liste, avec les 114 sourates et le téléchargement hors ligne comme les autres.

**Réglages → Synchroniser le catalogue** réinterroge les deux fournisseurs et met le résultat en cache : les nouveaux récitateurs publiés arrivent sans mise à jour de l'app.

---

## Ce que fait l'app

- **Récitateurs** — recherche insensible aux accents (latin et arabe), regroupement des variantes de translittération d'une même personne, filtres *Tous / Favoris / Mushaf complet / Hors ligne*, regroupement alphabétique, favoris.
- **Détail** — sélecteur de riwaya et de source quand le récitateur en propose plusieurs (Hafs, Warsh, murattal, mujawwad…), avec le nom exact fourni par chaque source, les 114 sourates, téléchargement à l'unité ou en bloc.
- **Lecteur** — arrière-plan et écran verrouillé, contrôles depuis le centre de contrôle et les AirPods, vignette dessinée à la volée, ±15 s, répétition sourate/série, reprise après interruption, pause au débranchement du casque.
- **Hors ligne** — regroupé par récitateur et version, poids par groupe, suppression fine ou globale, suivi des transferts en cours.
- **Réglages** — synchronisation, Wi-Fi uniquement, sources personnalisées, gestion du stockage.

---

## Organisation du code

```
project.yml                    définition du projet (XcodeGen)
build-ipa.sh                   compilation locale sur Mac
.github/workflows/build-ipa.yml  compilation sur runner macOS

Sources/
  App/          point d'entrée, délégué (session de téléchargement d'arrière-plan)
  Models/       Surah, Recitation, Reciter, Track, DownloadState
  Design/       Theme, LiquidGlass, IslamicPattern, Components
  Services/     Storage, CatalogStore, DownloadManager, PlayerService
  Views/        Root, Reciters, ReciterDetail, NowPlaying, Library, Settings
  Resources/    reciters.json (281 Ko), surahs.json (15 Ko)
  Assets.xcassets/  icône (Rub el Hizb doré), couleur d'accent
```

Le rendu « liquid glass » est écrit à la main (matériau flou + voile teinté + arête spéculaire + halos animés) plutôt que via l'API `glassEffect` d'iOS 26 : il compile dès **iOS 17** et reste identique quelle que soit la version du SDK.

---

## Sources et usage

L'audio est diffusé depuis :

- **MP3Quran.net** — 241 récitateurs, plusieurs riwayat
- **QuranicAudio.com** — 176 récitateurs

Les riwayat identifiées dans les métadonnées MP3Quran sont sélectionnables
depuis l'écran des récitateurs : Hafs ‘an ‘Asim, Warsh ‘an Nafi‘, Khalaf ‘an
Hamzah, Qalun ‘an Nafi‘, Ibn Kathir, Abu ‘Amr, Ya‘qub, Al-Kisa’i, Ibn ‘Amir,
Abu Ja‘far et Shu‘bah ‘an ‘Asim. Le filtre est mémorisé ; à l'intérieur d'un
récitateur, le choix de la version audio reste disponible.

Fusionnés par nom arabe normalisé : un même récitateur apparaît une fois, ses différentes versions regroupées.

**Tilawa ne redistribue aucun fichier.** Elle pointe vers ces serveurs et met en cache ce que tu choisis d'écouter hors ligne. Ces plateformes sont portées par des associations et vivent de dons : évite les téléchargements massifs. L'app limite volontairement à **2 connexions simultanées** pour cette raison.

Les métadonnées des sourates (noms arabes, translittérations, noms français, nombre de versets) proviennent de l'API de Quran.com.

---

## Limites connues

- Pas encore compilée (voir plus haut).
- Sans réseau **et** sans téléchargement, la lecture échoue — avec un message explicite.
- Certaines versions n'exposent pas les 114 sourates ; seules celles réellement disponibles sont affichées.
- Les noms des récitateurs viennent des fournisseurs : quelques translittérations sont approximatives.
- Les noms sont regroupés par identité arabe ou translittération normalisée ; les variantes d'orthographe restent visibles et chaque version audio garde son nom de source sélectionnable.
- Pas de lecture verset par verset ni de texte coranique affiché — l'app est un lecteur audio.
