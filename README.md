# MST2 CarPlay Maps – CarPlay-Navigation im Kombi für Delphi-MST2 (nur EU: `MST2_EU_VW_P0879D`)

**Deutsch zuerst – die englische Fassung steht darunter: [English version below](#english).**

> [!IMPORTANT]
> **Nur für das Gerät `MST2_EU_VW_P0879D` (EU, MU 0879, Variante `STD2Nav_EU_VW`).**
> Dieses Repository ist **ausschließlich für diesen Software-Stand** bestimmt. Es ist **nicht für Nordamerika (US/NAR)** und nicht für
> andere Geräte oder andere Züge gedacht – auch nicht für andere EU-Züge. Der Installer lehnt jedes abweichende Gerät ab.
> **Für US-Geräte bitte das Original-Repository verwenden:** <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>
>
> **Und nur mit dem Kombi der 1. Generation (Active Info Display, AID 1):** 12,3 Zoll, 1440×540 Pixel, verbaut von Produktionsstart 2016
> bis Kalenderwoche 47/2018. **Nicht geeignet** ist das **AID 2 / „Digital Cockpit Pro"** (10,25 Zoll, 1280×480 Pixel, ab Kalenderwoche
> 48/2018 und im Facelift ab 2020). Der Installer kann die Kombi-Generation nicht prüfen – das musst du selbst sicherstellen.
>
> **Vorgesehene Hardware** (Teilenummern, Angabe des Projekteigners): Radio **3Q0 035 864** (ohne Index-Buchstabe oder A, B, C;
> Delphi-MST2, Softwarestand `MST2_EU_VW_P0879D`) und Kombi **AID 1: 5NA 920 791** (ohne Index-Buchstabe oder A, B). Die Index-Buchstaben
> sind eine Annahme des Projekteigners; entwickelt wurde mit einem Gerät dieser Teilenummern, welche Indizes im Einzelnen passen, ist nicht geprüft. Der Installer kann Teilenummern nicht prüfen – er erkennt das Gerät
> nur an den Dateien der Firmware.

> [!CAUTION]
> **Unfertige Beta, am Fahrzeug noch NICHT geprüft.** Das Projekt verändert Startdateien des Infotainment-Geräts und kann eine
> Boot-Schleife auslösen. Nur mit stabiler Stromversorgung, funktionierendem Root-Zugang (serielle Konsole oder Telnet),
> geprüften Sicherungen und einem Wiederherstellungsweg ausprobieren. Nutzung auf eigene Gefahr, nur für den privaten Gebrauch.
> **Wenn etwas schiefgeht, brauchen wir unbedingt die Protokolle (Logs)!** Bitte nichts löschen und nichts aufräumen: den kompletten
> Protokollordner der SD-Karte (`sd_lauf…_<Kennung>`) bzw. die Ausgabe des Installers sichern und mit einer kurzen Beschreibung melden
> (ohne Namen gekoppelter Geräte, ohne Fahrgestell- und Seriennummern). Ohne Logs können wir den Fehler nicht finden.
> **Freiwillige Tester mit genau diesem Gerät sind willkommen:** siehe [`docs/TESTEN.md`](docs/TESTEN.md).

## Worum geht es

CarPlay-Routenführung (Pfeile, Straße, Distanz, Ankunftszeit, Spuren) und eine zweite Kartenansicht als Video für das
Digital-Cockpit (Active Info Display / Virtual Cockpit) an **Delphi-MST2**-Navigationsgeräten **des EU-Marktes**.

Dieses Repository ist eine **Weiterentwicklung (Fork)** des Originals für Nordamerika
[`tehfalcon-vw/mst2-nar-carplay-maps`](https://github.com/tehfalcon-vw/mst2-nar-carplay-maps) (MIT-Lizenz), das seinerseits auf
[`cartellone99/delphi-carplay-cluster-bridge`](https://github.com/cartellone99/delphi-carplay-cluster-bridge) (MIT-Lizenz) aufbaut.
Lizenz- und Herkunftshinweise stehen in [`LICENSE`](LICENSE) und [`NOTICE`](NOTICE).
**Alle Unterschiede zum Original** – was neu ist, was entfernt wurde, was gleich blieb – stehen in
[`docs/AENDERUNGEN.md`](docs/AENDERUNGEN.md); der Abgleich aller Daten mit den Firmwaredateien in
[`docs/FIRMWARE-ABGLEICH.md`](docs/FIRMWARE-ABGLEICH.md).

## Unterstütztes Gerät

Es gibt **genau ein** Ziel. Der Installer akzeptiert nur ein Gerät, dessen Dateien exakt zur Zielbeschreibung
[`targets/MST2_EU_VW_P0879D.json`](targets) passen; bei der kleinsten Abweichung tut er nichts.

| Zug (Train) | MU | Variante | Kombi | Kartenfenster (Video) | Stand |
|---|---|---|---|---|---|
| `MST2_EU_VW_P0879D` | 0879 | `STD2Nav_EU_VW` | **nur AID 1:** 12,3″, 1440×540 | 1010×376 (siehe unten) | gebaut und im Container geprobt, am Fahrzeug **nicht** erprobt |

Nicht geeignet: **Kombi der 2. Generation (AID 2)**, alle anderen Züge (auch andere EU-Züge), US-/NAR-Geräte, Geräte ohne Navigation, TechniSat/Preh-Geräte (Zug endet auf `T`).

Vorgesehene Hardware (Teilenummern, Angabe des Projekteigners – nicht aus der Firmware ableitbar und vom Installer nicht prüfbar; Index-Buchstaben: Annahme des Projekteigners, nicht geprüft):

| Bauteil | Teilenummer | Hinweis |
|---|---|---|
| Radio (Delphi-MST2, Navigation) | **3Q0 035 864** (ohne Index oder A, B, C) | Softwarestand `MST2_EU_VW_P0879D` (MU 0879) |
| Kombi, Active Info Display 1. Generation | **5NA 920 791** (ohne Index oder A, B) | 12,3″, 1440×540 |

## Kombi (Active Info Display)

| | **AID 1 – geeignet** | AID 2 – **nicht geeignet** |
|---|---|---|
| Name | Active Info Display, 1. Generation | Active Info Display, 2. Generation („Digital Cockpit Pro") |
| Größe | 12,3 Zoll, **1440×540** Pixel | 10,25 Zoll, 1280×480 Pixel |
| Verbaut | Produktionsstart 2016 bis Kalenderwoche 47/2018 | ab Kalenderwoche 48/2018 (Modelljahr 2019) und im Facelift ab 2020 |

(Angaben des Projekteigners; die Firmware selbst verrät die Kombi-Generation nicht.)

**Offener Punkt – Kartenfenster und Größenangabe:** Das Programm meldet dem iPhone ein Zusatzdisplay von **1010×376 Pixeln**, **244×91 mm**,
Sicherheitsfläche 1010×248 ab y = 58. Die Pixelzahl 1010×376 bestätigt der Projekteigner für sein Kombi; die Millimeterangabe und die Sicherheitsfläche stammen unverändert aus dem Original. Die 244×91 mm entsprechen rechnerisch der Fläche eines
10,25-Zoll-Panels im Format 8:3 (AID 2); ein 12,3-Zoll-Panel (AID 1) wäre etwa 293×110 mm. Ob die Angabe 244×91 mm zu einem AID 1 passt und
wie das iPhone die Größenangabe umsetzt (Maßstab, Schriftgrößen), ist **am Fahrzeug nicht geprüft** und wurde **nicht** angepasst. Tester
melden bitte, wie die Karte im Kombi aussieht (Foto).

## Was geprüft ist – und was nicht

Geprüft (ohne Fahrzeug):
- Protokoll-, Video- und Konfigurationsbausteine bestehen die Host-Tests (`npm test`, `ctest`).
- Die nativen ARM-Bibliotheken werden gebaut und per `readelf` auf Form und Importe geprüft.
- **Alle Daten wurden gegen die Firmwaredateien abgeglichen:** 14 Pflichtdateien (offizielle Prüfung über `EXTBIN_APPS.bin`)
  und 18 feste Adressen und Funktionsanfänge der Hooks (siehe [`docs/FIRMWARE-ABGLEICH.md`](docs/FIRMWARE-ABGLEICH.md)).
- Das HMI-Bündel lässt sich gegen das HMI des Zielgeräts übersetzen (alle aufgerufenen Stock-Methoden sind vorhanden).
- Der **Installer** wurde im Container auf einem Nachbau des Dateibaums durchgespielt (mit `mksh` und `dash`): Prüfmodus,
  Installation mit doppelter Sicherung (Gerät und SD-Karte), Abbruch bei nicht beschreibbarer SD-Karte, Deinstallation
  (Originale byteidentisch zurück, nichts bleibt auf dem Gerät), Ablehnung abweichender Dateien, Zurückrollen bei Fehlern,
  Erhalt einer Community-Variante von `runHMI.sh` (NavIgnore).

Nicht geprüft: **alles am echten Gerät** – Start, CarPlay-Verbindung, Routenführung im Kombi, Kartenvideo, Rückfall auf die
Werkskarte, Zündungswechsel.

## Aufbau

```text
iPhone (RGI-Nachrichten) -> iAP2-Treiber -> RGI-Dekoder -> Zustandsdatei -> HMI-Bündel -> NavBAP -> Kombi
iPhone (AirPlay-Stream 111) -> AirPlay-Hook -> H.264 -> MPEG-TS -> isoTX -> MOST -> Kombi-Karte
```

Einzelheiten stehen in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Geändert werden nur diese Dateien (werden vorher
gesichert): `cfg/iap2.cfg`, `hmi/HMI/runHMI.sh`, `hmi/HMI/config/bundles.properties` und `/etc/procman_core.cfg`.
Die Nutzlast liegt unter `/extbin/apps/mst2-eu-carplay-maps`.

## Voraussetzungen

1. Ein Gerät mit dem Zug **exakt** `MST2_EU_VW_P0879D` (in der Versionsanzeige prüfen) **und** ein Kombi der 1. Generation (AID 1, 12,3″, 1440×540).
2. Ein **bereits funktionierender Root-Zugang** (serielle Konsole oder Telnet). Dieses Projekt liefert weder Freischaltung noch
   Firmware noch Umgehung von Signaturen.
3. Eine FAT32-SD-Karte oder ein USB-Stick, vom Gerät lesbar und **beschreibbar** (dort wird eine zweite Sicherung abgelegt).
4. Stabile Stromversorgung bei Installation und erstem Start.
5. Eine Sicherung der Originalsoftware und ein **vorher erprobter Wiederherstellungsweg**.

## Bauen

Firmware ist **nicht** enthalten. Wer ein Paket bauen will, braucht die entpackte Original-Firmware (`apps.tmp` aus
`EXTBIN_APPS.bin`) des Zuges `MST2_EU_VW_P0879D`, die passende `STDF.bin` und ein aus `MIBHMI.jxe` umgewandeltes `MIBHMI.jar`.

Die Werkzeuge laufen in einem Linux-Container (Node 22, Clang, LLD, CMake):

```sh
docker build -t mst2d-build:local tools/docker
docker run --rm -v "$PWD":/work -w /work mst2d-build:local sh -c '
  npm test &&
  cmake -S native/rgi   -B build/rgi   && cmake --build build/rgi   && ctest --test-dir build/rgi   &&
  cmake -S native/video -B build/video && cmake --build build/video && ctest --test-dir build/video &&
  sh native/delphi-qnx/build.sh && sh native/delphi-qnx/verify.sh'
```

HMI-Bündel (JDK 8 erforderlich, Quelltext-Stufe 1.3):

```sh
sh hmi/test.sh
sh hmi/build.sh /pfad/zu/MIBHMI.jar
```

**Firmware gegen die Zielbeschreibung prüfen:**

```sh
node tools/analyze-firmware.cjs EXTBIN_APPS.bin bericht.json
node tools/verify-target.cjs bericht.json targets/MST2_EU_VW_P0879D.json
node tools/verify-static-bindings.cjs targets/MST2_EU_VW_P0879D.json /pfad/zu/apps.tmp
```

**Installierbares Paket bauen:**

```sh
node tools/build-stage.cjs targets/MST2_EU_VW_P0879D.json \
  /pfad/zu/apps.tmp /pfad/zu/STDF.bin native/delphi-qnx/build hmi/build/mst2-eu-rgi-hmi.jar /pfad/zu/leerem/ausgabeordner
```

**Probelauf des Installers ohne Fahrzeug** (im Container, auf einem Nachbau):

```sh
sh tools/rehearse-install.sh <stage-ordner> <apps.tmp> <procman_core.cfg> [<community-runHMI.sh> [<read-only-ordner>]]
```

## Installieren

1. Den Inhalt des Pakets in die Wurzel der Karte kopieren (`install.sh`, `uninstall.sh`, `stage.conf`, `payload/`, `patched/`).
2. Als root anmelden, die Verbindung für den ersten Neustart offen lassen, Karte einhängen und den Pfad prüfen (`mount`).
3. **Erst prüfen, nichts ändern:**

   ```sh
   ksh /pfad/zur/karte/install.sh --check
   ```

4. Wenn der Prüflauf besteht, iPhone trennen und installieren:

   ```sh
   ksh /pfad/zur/karte/install.sh
   ```

5. Nur bei der Meldung „Installation erfolgreich abgeschlossen" Karte entfernen und das Gerät **von Hand** neu starten.

Der Installer prüft **zuerst, ob die SD-Karte beschreibbar ist**; wenn nicht, bricht er ab, bevor am Gerät irgendetwas
geändert wird. Dann prüft er alle betroffenen Dateien (Größe und, falls `sha256sum` vorhanden ist, SHA-256).
**Jede Datei, die geändert oder überschrieben wird, wird doppelt gesichert** (und jede Kopie einzeln mit `cmp` geprüft):
auf dem Gerät in `/extbin/apps/mst2-eu-carplay-maps-backup` und zusätzlich auf der SD-Karte in `sd-backup/backup-<n>`
(neben dem Installer, mit `MANIFEST.txt`). Erst danach kopiert er die Nutzlast und prüft sie; bei einem Fehler stellt er die
Originale selbst wieder her und lässt beide Sicherungen liegen. Eine bekannte Community-Variante von `runHMI.sh` (zusätzliche
Zeile im Boot-Klassenpfad, z. B. der Dual-Navigations-Patch NavIgnore) bleibt erhalten; unser Jar wird nur an die erste
Zuweisung angehängt.

## Deinstallieren / Wiederherstellen

Mit eingehängter Karte und Root-Shell:

```sh
ksh /pfad/zur/karte/uninstall.sh
```

Der Deinstaller stellt die vier Originaldateien her und prüft sie, legt eine Kopie der Geräte-Sicherung auf der SD-Karte
ab (`sd-backup/vor-deinstallation-<n>`) und entfernt danach **alles von diesem Projekt vom Gerät**: die Nutzlast **und** die
Sicherung auf dem Gerät. Zum Schluss prüft er, dass nichts zurückgeblieben ist. **Die Sicherungen auf der SD-Karte bleiben
zur Analyse erhalten.** Startet das HMI nicht, aber die Root-Shell funktioniert noch, zuerst `uninstall.sh` ausführen. Ist
keine Shell mehr erreichbar, bleibt nur der vorher erprobte Wiederherstellungsweg.

## Freiwillige Tester

Wir suchen Tester mit genau diesem Gerät. Ablauf, Voraussetzungen und was berichtet werden soll: [`docs/TESTEN.md`](docs/TESTEN.md).

## Was dieses Repository nicht enthält

Keine Firmware, keine Signierschlüssel, keine Kartendaten, keine Herstellerdateien, keine Freischaltung von Telnet oder
Konsole, keine Fahrzeug- oder Personendaten. Ein Prüfskript im Entwicklungsablauf verhindert, dass solche Dateien
versehentlich eingecheckt werden. Beiträge dürfen deshalb ebenfalls nichts davon enthalten.

## Lizenz und Marken

Der Quelltext steht unter der [MIT-Lizenz](LICENSE). Volkswagen, Audi, Apple, CarPlay und weitere Marken gehören ihren
Inhabern. Dies ist ein unabhängiges Gemeinschaftsprojekt.

---

<a id="english"></a>

# MST2 CarPlay Maps – CarPlay navigation in the instrument cluster for Delphi MST2 (EU only: `MST2_EU_VW_P0879D`)

**English version of the German text above.**

> [!IMPORTANT]
> **Only for the unit `MST2_EU_VW_P0879D` (EU, MU 0879, variant `STD2Nav_EU_VW`).**
> This repository is intended **exclusively for this software state**. It is **not for North America (US/NAR)** and not for any
> other unit or train – not even for other EU trains. The installer refuses any other unit.
> **For US units please use the original repository:** <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>
>
> **And only with the first-generation cluster (Active Info Display, AID 1):** 12.3 inch, 1440×540 pixels, fitted from the start of
> production in 2016 up to calendar week 47/2018. **Not suitable** is the **AID 2 / "Digital Cockpit Pro"** (10.25 inch, 1280×480
> pixels, from calendar week 48/2018 and in the facelift from 2020). The installer cannot check the cluster generation – you must make sure yourself.
>
> **Intended hardware** (part numbers, statement of the project owner): radio **3Q0 035 864** (no index letter, or A, B, C;
> Delphi MST2, software stage `MST2_EU_VW_P0879D`) and cluster **AID 1: 5NA 920 791** (no index letter, or A, B). The index letters are an
> assumption of the project owner; it was developed with a unit of these part numbers, which indices fit is not verified. The installer cannot check part numbers – it recognises the unit only by the firmware files.

> [!CAUTION]
> **Unfinished beta, NOT yet verified in a vehicle.** This project modifies startup files of the infotainment unit and can cause a
> boot loop. Try it only with stable power, a working root shell (serial console or Telnet), verified backups and a recovery
> method. Use at your own risk, for private use only.
> **If anything goes wrong we absolutely need the logs!** Please do not delete or tidy up anything: save the complete log folder on the SD card
> (`sd_lauf…_<ID>`) or the installer output and report it with a short description (without names of paired devices, without VIN and
> serial numbers). Without logs we cannot find the error.
> **Volunteer testers with exactly this unit are welcome:** see [`docs/TESTEN.md`](docs/TESTEN.md).

## What it is

CarPlay turn guidance (arrows, street, distance, arrival time, lanes) and a secondary map video for the digital cockpit
(Active Info Display / Virtual Cockpit) on **Delphi MST2** navigation units **of the EU market**.

This repository is a **continuation (fork)** of the North American original
[`tehfalcon-vw/mst2-nar-carplay-maps`](https://github.com/tehfalcon-vw/mst2-nar-carplay-maps) (MIT license), which in turn builds on
[`cartellone99/delphi-carplay-cluster-bridge`](https://github.com/cartellone99/delphi-carplay-cluster-bridge) (MIT license).
License and attribution notices are in [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
**All differences from the original** – what is new, what was removed, what stayed the same – are listed in
[`docs/AENDERUNGEN.md`](docs/AENDERUNGEN.md); the comparison of all data with the firmware files is in
[`docs/FIRMWARE-ABGLEICH.md`](docs/FIRMWARE-ABGLEICH.md).

## Supported unit

There is **exactly one** target. The installer accepts only a unit whose files match the target description
[`targets/MST2_EU_VW_P0879D.json`](targets) exactly; on the slightest mismatch it does nothing.

| Train | MU | Variant | Cluster | Map window (video) | Status |
|---|---|---|---|---|---|
| `MST2_EU_VW_P0879D` | 0879 | `STD2Nav_EU_VW` | **AID 1 only:** 12.3″, 1440×540 | 1010×376 (see below) | built and rehearsed in a container, **not** tested in a vehicle |

Not suitable: **second-generation cluster (AID 2)**, all other trains (including other EU trains), US/NAR units, units without navigation, TechniSat/Preh units (train ends in `T`).

Intended hardware (part numbers, statement of the project owner – not derivable from the firmware and not checkable by the installer; index letters: assumption of the project owner, not verified):

| Component | Part number | Note |
|---|---|---|
| Radio (Delphi MST2, navigation) | **3Q0 035 864** (no index, or A, B, C) | software stage `MST2_EU_VW_P0879D` (MU 0879) |
| Cluster, Active Info Display 1st generation | **5NA 920 791** (no index, or A, B) | 12.3″, 1440×540 |

## Cluster (Active Info Display)

| | **AID 1 – suitable** | AID 2 – **not suitable** |
|---|---|---|
| Name | Active Info Display, 1st generation | Active Info Display, 2nd generation ("Digital Cockpit Pro") |
| Size | 12.3 inch, **1440×540** pixels | 10.25 inch, 1280×480 pixels |
| Fitted | start of production 2016 to calendar week 47/2018 | from calendar week 48/2018 (model year 2019) and in the facelift from 2020 |

(Information from the project owner; the firmware itself does not reveal the cluster generation.)

**Open point – map window and size information:** the program advertises an auxiliary display of **1010×376 pixels**, **244×91 mm**, safe
area 1010×248 from y = 58, to the iPhone. The project owner confirms the pixel size 1010×376 for the cluster; the millimetre size and the safe area are taken over unchanged from the original. 244×91 mm is, by calculation, the area of a 10.25 inch panel in 8:3
format (AID 2); a 12.3 inch panel (AID 1) would be about 293×110 mm. Whether the 244×91 mm figure fits an AID 1 and how the iPhone applies the size
information (scale, font sizes) is **not verified in a vehicle** and was **not** adapted. Testers, please report what the map looks like in the
cluster (photo).

## What is verified – and what is not

Verified (without a vehicle):
- Protocol, video and configuration building blocks pass the host tests (`npm test`, `ctest`).
- The native ARM libraries are built and checked with `readelf` for shape and imports.
- **All data were compared with the firmware files:** 14 required files (official check via `EXTBIN_APPS.bin`) and 18 fixed
  addresses and function prologues of the hooks (see [`docs/FIRMWARE-ABGLEICH.md`](docs/FIRMWARE-ABGLEICH.md)).
- The HMI bundle compiles against the HMI of the target unit (every stock method it calls exists).
- The **installer** was rehearsed in a container on a mock file tree (with `mksh` and `dash`): check mode, install with double
  backup (unit and SD card), abort when the SD card is not writable, uninstall (originals restored byte for byte, nothing
  stays on the unit), refusal of modified files, rollback on errors, preservation of a community variant of `runHMI.sh` (NavIgnore).

Not verified: **everything on a real unit** – boot, CarPlay connection, guidance in the cluster, map video, fallback to the
factory map, ignition cycles.

## Architecture

```text
iPhone (RGI messages)       -> iAP2 driver -> RGI decoder -> state file -> HMI bundle -> NavBAP -> cluster
iPhone (AirPlay stream 111) -> AirPlay hook -> H.264 -> MPEG-TS -> isoTX -> MOST -> cluster map
```

Details are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Only these files are modified (backed up first):
`cfg/iap2.cfg`, `hmi/HMI/runHMI.sh`, `hmi/HMI/config/bundles.properties` and `/etc/procman_core.cfg`. The payload lives
under `/extbin/apps/mst2-eu-carplay-maps`.

## Requirements

1. A unit with the train **exactly** `MST2_EU_VW_P0879D` (check the version screen) **and** a first-generation cluster (AID 1, 12.3″, 1440×540).
2. An **already working root shell** (serial console or Telnet). This project provides no unlock, no firmware and no signature bypass.
3. A FAT32 SD card or USB drive readable **and writable** by the unit (a second backup is stored there).
4. Stable power during installation and first boot.
5. A backup of the original software and a **recovery method you have tried beforehand**.

## Build

Firmware is **not** included. To build a package you need the unpacked stock firmware (`apps.tmp` from `EXTBIN_APPS.bin`) of the
train `MST2_EU_VW_P0879D`, the matching `STDF.bin` and a `MIBHMI.jar` converted from `MIBHMI.jxe`.

The tools run in a Linux container (Node 22, Clang, LLD, CMake):

```sh
docker build -t mst2d-build:local tools/docker
docker run --rm -v "$PWD":/work -w /work mst2d-build:local sh -c '
  npm test &&
  cmake -S native/rgi   -B build/rgi   && cmake --build build/rgi   && ctest --test-dir build/rgi   &&
  cmake -S native/video -B build/video && cmake --build build/video && ctest --test-dir build/video &&
  sh native/delphi-qnx/build.sh && sh native/delphi-qnx/verify.sh'
```

HMI bundle (JDK 8 required, source level 1.3):

```sh
sh hmi/test.sh
sh hmi/build.sh /path/to/MIBHMI.jar
```

**Verify the firmware against the target description:**

```sh
node tools/analyze-firmware.cjs EXTBIN_APPS.bin report.json
node tools/verify-target.cjs report.json targets/MST2_EU_VW_P0879D.json
node tools/verify-static-bindings.cjs targets/MST2_EU_VW_P0879D.json /path/to/apps.tmp
```

**Build an installable package:**

```sh
node tools/build-stage.cjs targets/MST2_EU_VW_P0879D.json \
  /path/to/apps.tmp /path/to/STDF.bin native/delphi-qnx/build hmi/build/mst2-eu-rgi-hmi.jar /path/to/empty/output-dir
```

**Rehearse the installer without a vehicle** (in the container, on a mock tree):

```sh
sh tools/rehearse-install.sh <stage-dir> <apps.tmp> <procman_core.cfg> [<community-runHMI.sh> [<read-only-dir>]]
```

## Install

1. Copy the package contents to the root of the card (`install.sh`, `uninstall.sh`, `stage.conf`, `payload/`, `patched/`).
2. Log in as root, keep the connection open for the first reboot, mount the card and check the path (`mount`).
3. **Check first, change nothing:**

   ```sh
   ksh /path/to/card/install.sh --check
   ```

4. If the check passes, disconnect the iPhone and install:

   ```sh
   ksh /path/to/card/install.sh
   ```

5. Only after "Installation completed successfully", remove the card and reboot the unit **manually**.

The installer **first checks that the SD card is writable**; if not, it aborts before anything on the unit is changed. Then it
verifies every affected file (size and, if `sha256sum` exists, SHA-256). **Every file that is modified or overwritten is backed
up twice** (and each copy is verified with `cmp`): on the unit in `/extbin/apps/mst2-eu-carplay-maps-backup` and additionally on
the SD card in `sd-backup/backup-<n>` (next to the installer, with a `MANIFEST.txt`). Only then does it copy and verify the
payload; on any error it restores the originals itself and leaves both backups in place. A known community variant of
`runHMI.sh` (an extra boot class path line, for example the NavIgnore dual navigation patch) is preserved; our jar is only
appended to the first assignment.

## Uninstall / recover

With the card mounted and a root shell:

```sh
ksh /path/to/card/uninstall.sh
```

The uninstaller restores the four stock files and verifies them, stores a copy of the on-unit backup on the SD card
(`sd-backup/vor-deinstallation-<n>`) and then removes **everything of this project from the unit**: the payload **and** the
backup on the unit. Finally it checks that nothing is left. **The backups on the SD card are kept for analysis.** If the HMI
does not start but the root shell still works, run `uninstall.sh` first. If no shell is reachable any more, only the recovery
method you prepared beforehand remains.

## Volunteer testers

We are looking for testers with exactly this unit. Procedure, requirements and what to report: [`docs/TESTEN.md`](docs/TESTEN.md).

## What this repository does not contain

No firmware, no signing material, no map data, no vendor files, no Telnet or console unlock, no vehicle or personal data. A
check script in the development workflow prevents such files from being committed by accident. Contributions must not contain
any of this either.

## License and trademarks

The source is available under the [MIT License](LICENSE). Volkswagen, Audi, Apple, CarPlay and other trademarks belong to their
respective owners. This is an independent community project.
