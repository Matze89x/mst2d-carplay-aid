# Änderungen gegenüber der US-Originalversion

**Deutsch zuerst – English version below: [English](#english).**

> **Dieses Repository ist ausschließlich für den EU-Markt und das Gerät `MST2_EU_VW_P0879D` bestimmt.**
> Es ist **nicht** für Nordamerika (US/NAR) und nicht für andere Geräte gedacht. Für das US-Gerät `MST2_US_VW_P0867D` bitte das
> Original-Repository verwenden: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.
> **Alles hier ist noch nicht am Fahrzeug geprüft** (siehe unten und [`TESTEN.md`](TESTEN.md)).

Ausgangspunkt ist das Original `tehfalcon-vw/mst2-nar-carplay-maps` (Version 0.1.0-beta.1, MIT-Lizenz), das auf
`cartellone99/delphi-carplay-cluster-bridge` (MIT) aufbaut. Die Lizenz- und Herkunftshinweise bleiben in `LICENSE` und
`NOTICE` erhalten. Die frühere Entwicklung steht unverändert in der Git-Historie.

## 1. Zielgerät und Markt

- **Neu:** Zielbeschreibung [`targets/MST2_EU_VW_P0879D.json`](../targets/MST2_EU_VW_P0879D.json) für den Zug `MST2_EU_VW_P0879D`
  (MU `0879`, Variante `STD2Nav_EU_VW`), erzeugt mit `tools/make-target.cjs` aus dem originalen Firmwarepaket.
- **Entfernt:** die Zielbeschreibung des US-Geräts (`MST2_US_VW_P0867D`), die US-spezifische Befehlshülle für den Paketbau
  (`tools/build-p0867d-stage.cjs`) und alle US-/NAR-Bezüge in Dokumentation, Tests und Meldungen.
  **Unterstützung für US-Geräte gibt es hier nicht mehr.**
- `tools/verify-target.cjs` akzeptiert nur noch Ziele der Region `EU`; `tools/build-iap2-config.cjs` prüft gegen das EU-Ziel.
- **Kombi:** nur Active Info Display der 1. Generation (AID 1; 12,3 Zoll, 1440×540 Pixel; Produktion bis Kalenderwoche 47/2018).
  **Nicht geeignet:** AID 2 / „Digital Cockpit Pro" (10,25 Zoll, 1280×480; ab Kalenderwoche 48/2018 und Facelift). Neu in der
  Zielbeschreibung (`cluster`), im README, in `TESTEN.md` und in der Installer-Meldung; der Installer kann es nicht prüfen.
- **Vorgesehene Hardware:** Radio **3Q0 035 864** (ohne Index-Buchstabe oder A, B, C; Delphi-MST2, Softwarestand `MST2_EU_VW_P0879D`) und Kombi
  **AID 1: 5NA 920 791** (ohne Index-Buchstabe oder A, B); Angabe und Annahme des Projekteigners, nicht geprüft. Das Original nennt nur Zug und Variante, keine Teilenummern. Neu in der
  Zielbeschreibung (`hardware`), im README, in `TESTEN.md` und in der Installer-Meldung; der Installer kann Teilenummern nicht prüfen.
- **Kartenfenster:** 1010×376 Pixel (nach Angabe des Projekteigners die Kartenfläche seines Kombis; Sicherheitsfläche 1010×248 ab y = 58) und die Größenangabe 244×91 mm **unverändert aus dem Original**.
  **Offener Punkt:** 244×91 mm entsprechen rechnerisch einem 10,25-Zoll-Panel (AID 2); ein 12,3-Zoll-Panel wäre etwa 293×110 mm. Ob die
  Werte zu einem AID 1 passen, ist am Fahrzeug nicht geprüft; sie wurden bewusst nicht ohne Test geändert.

## 2. Firmware-Abgleich

Alle Daten wurden gegen die Firmwaredateien verglichen; Einzelheiten und Tabellen in
[`FIRMWARE-ABGLEICH.md`](FIRMWARE-ABGLEICH.md). Kurz: Von 14 Pflichtdateien sind **6 bytegleich** mit dem Original
(iAP2-Treiber, `libiap2client`, `libAirPlay`, `libAirPlaySupport`, `dsiifc.jar`, `mm-ipod`), **8 weichen ab**
(`iap2.cfg`, `MediaHandler`, `runHMI.sh`, `bundles.properties`, `CarPlay`, `ClusterServices`, `NavigationServer`, `Most`); dazu
unterscheiden sich `STDF.bin` und `procman_core.cfg` (6408 → 6444 Byte). Alle 18 festen Adressen und Funktionsanfänge der
Hooks stimmen mit der EU-Firmware überein.

## 3. Programmcode

- **`native/` (RGI-Kern, Video, QNX-Hooks):** Die Logik ist **unverändert**. Geändert wurden nur Bezeichner und Meldungen
  (siehe Tabelle in Abschnitt 8). Die Hook-Adressen sind dieselben, weil die betroffenen Bibliotheken bytegleich sind.
- **`hmi/` (Java-Bündel):** Verhalten **unverändert**, nur das Paket heißt jetzt `mst2.eu.cluster`. Es lässt sich gegen das
  `MIBHMI` des EU-Geräts übersetzen; alle sieben aufgerufenen Stock-Klassen und die Ereignisnummern für die Sichtbarkeit der
  Karte (`1074841845`, `1074841846`) sind dort vorhanden.
- **Neu:** `hmi/build.sh` und `hmi/test.sh` (Linux/macOS) neben den PowerShell-Skripten.

## 4. Paketbau und Werkzeuge

- **`tools/build-stage.cjs`** (neu, allgemein) ersetzt den US-spezifischen Bauer. Es erzeugt zusätzlich `stage.conf` mit den
  Erwartungswerten des Ziels, die der Installer liest.
- **`tools/make-target.cjs`** (neu): erzeugt eine Zielbeschreibung aus einer Firmware und bricht ab, wenn die Funktionsanfänge
  nicht zur Vorlage passen.
- **`tools/verify-static-bindings.cjs`** (neu): prüft die festen Adressen gegen die entpackte Firmware (18 Prüfungen).
- **`tools/rehearse-install.sh`** (neu): spielt Prüfen, Installieren und Deinstallieren auf einem Nachbau des Dateibaums durch.
- **`tools/docker/Dockerfile`** (neu): Linux-Umgebung für Bau und Tests (Node 22, Clang, LLD, CMake, `mksh`).
- **Änderung `runHMI.sh`:** Das Original ersetzte die ganze Datei durch eine fertig gebaute Fassung. Jetzt wird **nur die erste
  Zuweisung des Boot-Klassenpfads** byte-genau um unser Jar ergänzt; der Rest der Datei bleibt unverändert. So bleibt eine
  bekannte Community-Variante (zusätzliche Zeile, z. B. der Dual-Navigations-Patch NavIgnore) erhalten. Die Zielbeschreibung
  kennt diese Variante als `knownVariants`.

## 5. Installer und Deinstaller

- Gesteuert von `stage.conf` statt fest eingebauter Werte; **Prüfmodus** `ksh install.sh --check` ändert nichts.
- **SD-Karte zuerst:** Ist die SD-Karte nicht beschreibbar, wird **vor jeder Änderung** abgebrochen (auch im Prüfmodus gemeldet).
- **Doppelte Sicherung:** Jede geänderte oder überschriebene Datei wird auf dem Gerät **und** auf der SD-Karte gesichert,
  jede Kopie einzeln mit `cmp` geprüft, auf der Karte zusätzlich `MANIFEST.txt`. Vorhandene Sicherungsordner werden nie überschrieben.
- Bei einem Fehler stellt der Installer die Originale selbst her und lässt beide Sicherungen liegen.
- **Deinstaller:** stellt die Originale her und prüft sie, legt eine Kopie der Geräte-Sicherung auf der SD-Karte ab und
  entfernt dann **alles** von diesem Projekt vom Gerät (Nutzlast **und** Sicherung auf dem Gerät), prüft auf Reste.
  Die Sicherungen auf der SD-Karte bleiben zur Analyse erhalten. `BACKUP_DIR_OVERRIDE` erlaubt die Wiederherstellung aus
  einer Kopie der Sicherung.
- Meldungen zweisprachig (Deutsch zuerst); Löschziele mit `${VAR:?}` abgesichert.
- **Beta 2, Werkzeug-Schicht `installer/tools.sh`:** Der erste Test in einem echten Radio (Beta 1) brach sofort ab, weil dem Radio beim
  Start `dirname`, `cksum`, `id`, `tail`, `uptime` und `expr` fehlen. Seitdem rufen die Skripte direkt nur noch `cp rm mkdir rmdir chmod ls mount grep`
  auf; alles andere geht über Funktionen, die das Programm nutzen, wenn es da ist, und sonst eine reine Shell-Lösung verwenden (Vergleich:
  `cmp`, `diff`, SHA-256, `cksum`, zuletzt nur die Größe). Fehlt etwas Zwingendes, bricht der Installer **vor jeder Änderung** mit einer klaren Meldung ab.
  Die Prüfung der Zeilen von `runHMI.sh` ist byte-genau ohne `head`/`tail`. Das SD-Skript schreibt zusätzlich `werkzeuge_<KENNUNG>.txt`
  (PATH und Inhalt der Programmordner des Radios). Die Proben laufen jetzt auch in einer eingeschränkten Umgebung (`LIMITED=1`).
- **Beta 3:** Der zweite Test im Radio zeigte die echte Programmliste (u. a. **kein `rmdir`**, `cmp`, `wc`, `head`, `tail`, `sha256sum`; vorhanden `awk`, `touch`, `date`, `sync`, `mv`, `cat`).
  `rmdir` ist nicht mehr zwingend (Ersatz: `rm -r`, nur bei leerem Ordner). Proben jetzt mit genau dieser Liste (`LIMITED=1`) und mit nur den sieben zwingenden Programmen (`LIMITED=2`).

## 6. Tests

24 Tests statt 19 im Original (Host-Tests, `npm test`), dazu die unveränderten CMake-Tests (RGI 4, Video 7), die ARM-Prüfung
und der Installer-Probelauf. Neu: Tests für den allgemeinen Paketbau, `stage.conf`, die EU-Zielbeschreibung, den Erhalt
fremder Zuweisungen im Boot-Klassenpfad sowie die SD-Prüfung und das vollständige Entfernen.

## 7. Dokumentation

README, `ARCHITECTURE.md` und die Unter-READMEs sind zweisprachig (Deutsch zuerst, Englisch darunter); neu sind
`FIRMWARE-ABGLEICH.md`, diese Datei und [`TESTEN.md`](TESTEN.md).

## 8. Umbenannte Bezeichner (nicht mit dem Original mischbar)

| Original (US) | Hier (EU) |
|---|---|
| `/extbin/apps/mst2-nar-carplay-maps` | `/extbin/apps/mst2-eu-carplay-maps` |
| `/extbin/apps/mst2-nar-carplay-maps-backup` | `/extbin/apps/mst2-eu-carplay-maps-backup` |
| `libmst2_nar_ipod.so`, `…_launch.so`, `…_video_gate.so`, `…_airplay.so` | `libmst2_eu_ipod.so`, `…_launch.so`, `…_video_gate.so`, `…_airplay.so` |
| `mst2-nar-rgi-hmi.jar` | `mst2-eu-rgi-hmi.jar` |
| Java-Paket `mst2.nar.cluster`, Bündelname `MST2NARRGI` | `mst2.eu.cluster`, `MST2EURGI` |
| `/dev/shmem/mst2-nar-rgi.state`, `…-ready`, `….log`, `mst2_nar_alt111` | `/dev/shmem/mst2-eu-rgi.state`, `…-ready`, `….log`, `mst2_eu_alt111` |
| iAP2-Komponentenname `MST2 NAR Cluster` | `MST2 EUR Cluster` (gleiche Länge, 16 Zeichen) |
| C-Symbole `dcc_p0867d_airplay_resolve`, `struct dcc_p0867d_airplay_target` | `dcc_airplay_hook_resolve`, `struct dcc_airplay_hook_target` |

Der geänderte iAP2-Komponentenname ist das Einzige, was ein iPhone sieht; er wurde nicht am Gerät geprüft.

## 9. Unverändert

RGI-Dekoder und Sitzungslogik, Videopipeline (AVCC → Annex B, MPEG-TS, Wiederherstellung auf den Werkspfad), Hook-Logik,
Verhalten des HMI-Bündels, `LICENSE` und `NOTICE`.

## 10. Was geprüft ist – und was nicht

Geprüft (ohne Fahrzeug): Host- und Protokolltests, ARM-Bau und -Prüfung, Übersetzung des HMI-Bündels gegen das EU-`MIBHMI`,
Firmware-Abgleich (siehe oben), Installer-Probelauf auf einem Nachbau (Prüfmodus, Installation, doppelte Sicherung, nicht
beschreibbare SD-Karte, Rückrollen, Deinstallation, Erhalt der Community-Variante).
**Nicht geprüft:** alles am echten Gerät (Start, CarPlay-Verbindung, Führung im Kombi, Kartenvideo, Rückfall auf die
Werkskarte, Zündungswechsel). Auch das Original ist nach Angabe seines Autors am Fahrzeug nicht erprobt.
**Freiwillige Tester sind willkommen** – bitte [`TESTEN.md`](TESTEN.md) lesen.

---

<a id="english"></a>

# Changes compared to the US original

> **This repository is intended exclusively for the EU market and the unit `MST2_EU_VW_P0879D`.**
> It is **not** for North America (US/NAR) and not for any other unit. For the US unit `MST2_US_VW_P0867D` please use the
> original repository: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.
> **Everything here is not yet verified in a vehicle** (see below and [`TESTEN.md`](TESTEN.md)).

The starting point is the original `tehfalcon-vw/mst2-nar-carplay-maps` (version 0.1.0-beta.1, MIT license), which builds on
`cartellone99/delphi-carplay-cluster-bridge` (MIT). License and attribution notices remain in `LICENSE` and `NOTICE`. The
earlier development stays unchanged in the git history.

## 1. Target unit and market

- **New:** target description [`targets/MST2_EU_VW_P0879D.json`](../targets/MST2_EU_VW_P0879D.json) for the train
  `MST2_EU_VW_P0879D` (MU `0879`, variant `STD2Nav_EU_VW`), generated with `tools/make-target.cjs` from the original firmware package.
- **Removed:** the target description of the US unit (`MST2_US_VW_P0867D`), the US-specific wrapper command for package
  building (`tools/build-p0867d-stage.cjs`) and every US/NAR reference in documentation, tests and messages.
  **There is no support for US units here any more.**
- `tools/verify-target.cjs` accepts only targets of region `EU`; `tools/build-iap2-config.cjs` checks against the EU target.
- **Cluster:** only the first-generation Active Info Display (AID 1; 12.3 inch, 1440×540 pixels; production up to calendar week
  47/2018). **Not suitable:** AID 2 / "Digital Cockpit Pro" (10.25 inch, 1280×480; from calendar week 48/2018 and facelift). New in the
  target description (`cluster`), in the README, in `TESTEN.md` and in the installer message; the installer cannot check it.
- **Intended hardware:** radio **3Q0 035 864** (no index letter, or A, B, C; Delphi MST2, software stage `MST2_EU_VW_P0879D`) and cluster
  **AID 1: 5NA 920 791** (no index letter, or A, B); statement and assumption of the project owner, not verified. The original names only train and variant, no part numbers. New in the target
  description (`hardware`), in the README, in `TESTEN.md` and in the installer message; the installer cannot check part numbers.
- **Map window:** 1010×376 pixels (according to the project owner the map area of his cluster; safe area 1010×248 from y = 58) and the size information 244×91 mm **unchanged from the original**.
  **Open point:** 244×91 mm is, by calculation, a 10.25 inch panel (AID 2); a 12.3 inch panel would be about 293×110 mm. Whether the
  values fit an AID 1 is not verified in a vehicle; they were deliberately not changed without a test.

## 2. Firmware comparison

All data were compared against the firmware files; details and tables in [`FIRMWARE-ABGLEICH.md`](FIRMWARE-ABGLEICH.md).
In short: of 14 required files **6 are byte-identical** with the original (iAP2 driver, `libiap2client`, `libAirPlay`,
`libAirPlaySupport`, `dsiifc.jar`, `mm-ipod`), **8 differ** (`iap2.cfg`, `MediaHandler`, `runHMI.sh`, `bundles.properties`,
`CarPlay`, `ClusterServices`, `NavigationServer`, `Most`); `STDF.bin` and `procman_core.cfg` (6408 → 6444 bytes) differ too.
All 18 fixed addresses and function prologues of the hooks match the EU firmware.

## 3. Program code

- **`native/` (RGI core, video, QNX hooks):** logic is **unchanged**. Only identifiers and messages were changed (table in
  section 8). The hook addresses are the same because the affected libraries are byte-identical.
- **`hmi/` (Java bundle):** behavior **unchanged**, only the package is now `mst2.eu.cluster`. It compiles against the
  `MIBHMI` of the EU unit; all seven stock classes it calls and the event numbers for map visibility (`1074841845`,
  `1074841846`) exist there.
- **New:** `hmi/build.sh` and `hmi/test.sh` (Linux/macOS) next to the PowerShell scripts.

## 4. Package build and tools

- **`tools/build-stage.cjs`** (new, generic) replaces the US-specific builder. It also writes `stage.conf` with the target's
  expected values, which the installer reads.
- **`tools/make-target.cjs`** (new): generates a target description from a firmware and aborts if the function prologues do
  not match the template.
- **`tools/verify-static-bindings.cjs`** (new): checks the fixed addresses against the unpacked firmware (18 checks).
- **`tools/rehearse-install.sh`** (new): rehearses check, install and uninstall on a mock file tree.
- **`tools/docker/Dockerfile`** (new): Linux environment for build and tests (Node 22, Clang, LLD, CMake, `mksh`).
- **Change to `runHMI.sh`:** the original replaced the whole file with a prebuilt version. Now **only the first boot class
  path assignment** is extended byte-exactly with our jar; the rest of the file stays unchanged. A known community variant
  (an extra line, e.g. the NavIgnore dual-navigation patch) is therefore preserved. The target description lists this variant
  under `knownVariants`.

## 5. Installer and uninstaller

- Driven by `stage.conf` instead of built-in values; **check mode** `ksh install.sh --check` changes nothing.
- **SD card first:** if the SD card is not writable, it aborts **before any change** (also reported in check mode).
- **Double backup:** every modified or overwritten file is backed up on the unit **and** on the SD card, each copy verified
  with `cmp`, plus `MANIFEST.txt` on the card. Existing backup directories are never overwritten.
- On any error the installer restores the originals itself and leaves both backups in place.
- **Uninstaller:** restores and verifies the originals, stores a copy of the on-unit backup on the SD card and then removes
  **everything** of this project from the unit (payload **and** backup on the unit), checking for leftovers. The backups on
  the SD card are kept for analysis. `BACKUP_DIR_OVERRIDE` allows restoring from a copy of the backup.
- Messages are bilingual (German first); removal targets are guarded with `${VAR:?}`.
- **Beta 2, tool layer `installer/tools.sh`:** the first test in a real radio (beta 1) stopped at once because the radio lacks `dirname`,
  `cksum`, `id`, `tail`, `uptime` and `expr` at boot. The scripts now call only `cp rm mkdir rmdir chmod ls mount grep` directly; everything else goes
  through functions that use the program if it exists and a pure shell solution otherwise (comparison: `cmp`, `diff`, SHA-256, `cksum`, last resort size only).
  If something essential is missing, the installer aborts **before any change** with a clear message. The `runHMI.sh` line edit is byte-exact without
  `head`/`tail`. The SD script additionally writes `werkzeuge_<ID>.txt` (PATH and the contents of the radio's program folders). The rehearsals now also run
  in a restricted environment (`LIMITED=1`).
- **Beta 3:** the second test in a radio showed the real program list (among others **no `rmdir`**, `cmp`, `wc`, `head`, `tail`, `sha256sum`; present are `awk`, `touch`, `date`, `sync`, `mv`, `cat`).
  `rmdir` is no longer essential (fallback: `rm -r`, only for an empty folder). Rehearsals now run with exactly this list (`LIMITED=1`) and with only the seven essential programs (`LIMITED=2`).

## 6. Tests

24 tests instead of 19 in the original (host tests, `npm test`), plus the unchanged CMake tests (RGI 4, video 7), the ARM
verification and the installer rehearsal. New: tests for the generic package build, `stage.conf`, the EU target description,
preservation of foreign boot class path assignments, the SD check and complete removal.

## 7. Documentation

README, `ARCHITECTURE.md` and the sub-READMEs are bilingual (German first, English below); new are `FIRMWARE-ABGLEICH.md`,
this file and [`TESTEN.md`](TESTEN.md).

## 8. Renamed identifiers (not mixable with the original)

See the table in the German section (original US → here EU): install and backup directories, the four preload libraries, the
HMI jar, the Java package and bundle name, the shared-memory paths, the iAP2 component name (`MST2 NAR Cluster` →
`MST2 EUR Cluster`, same length of 16 characters) and two C symbols. The changed iAP2 component name is the only thing an iPhone
sees; it was not tested on a unit.

## 9. Unchanged

RGI decoder and session logic, video pipeline (AVCC → Annex B, MPEG-TS, fallback to the factory path), hook logic, behavior
of the HMI bundle, `LICENSE` and `NOTICE`.

## 10. What is verified – and what is not

Verified (without a vehicle): host and protocol tests, ARM build and verification, compiling the HMI bundle against the EU
`MIBHMI`, firmware comparison (see above), installer rehearsal on a mock tree (check mode, install, double backup, non-writable
SD card, rollback, uninstall, preservation of the community variant).
**Not verified:** everything on a real unit (boot, CarPlay connection, guidance in the cluster, map video, fallback to the
factory map, ignition cycles). The original, too, is untested in a vehicle according to its author.
**Volunteer testers are welcome** – please read [`TESTEN.md`](TESTEN.md).
