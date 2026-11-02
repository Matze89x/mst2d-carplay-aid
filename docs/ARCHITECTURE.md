# Architektur

**Deutsch zuerst – die englische Fassung steht darunter: [English version below](#architecture).**

Die Beta ergänzt die Originalsoftware des Ziels (`MST2_EU_VW_P0879D`) um zwei unabhängige CarPlay-Wege.

## Routenführung

```text
iPhone-RGI-Nachrichten
  -> originaler mm-ipod-Transport
  -> begrenzter RGI-Dekoder mit Sitzungsspeicher
  -> gemeinsame Zustandsdatei
  -> spät geladenes HMI-Bündel im ASL-Thread
  -> originale NavBAP- und ClusterServices-Schnittstellen
  -> Führung im Virtual Cockpit
```

Die iAP2-Vorladebibliothek meldet nur die Nachrichtengruppe `0x52` an, nachdem sie bestätigt hat, dass die exakten
Tabellen des Ziels unverändert sind. Unbekannte Nachrichten bleiben beim Original. Fehlerhafte oder veraltete Eingaben
löschen den eigenen Zustand, ohne den originalen Verteiler zu ersetzen.

## Zweite Kartenansicht als Video

```text
iPhone-AirPlay-Stream 111
  -> auf das Ziel fest abgestimmte libAirPlay-Hooks
  -> fortlaufendes AES-CTR und Screen-Paket-Parser
  -> AVCC-zu-Annex-B-Umwandlung und IDR-Sperre
  -> Speicherplatz für das neueste Bild im gemeinsamen Speicher
  -> MPEG-TS-Arbeiter im NavigationServer
  -> /dev/transport_server/spawn/isoTX
  -> MOST GfxStreamSink
  -> Karte im Virtual Cockpit
```

Der Empfänger meldet ein Zusatzdisplay mit 1010×376 Pixeln (244×91 mm, aus dem Original übernommen; das Kombi des Ziels ist ein AID 1 mit 12,3 Zoll und 1440×540 Pixeln – Passung am Fahrzeug nicht geprüft, siehe README). Der Transport nutzt H.264 mit PID `0x11`, PMT-PID `0x1000`,
aus der Quelle abgeleitete PTS, PCR und Schreibvorgänge zu je 64 Paketen. Die Ausgabe des originalen NavigationServers
wird erst unterdrückt, wenn der erste vollständige eigene Block gelungen ist. Bei Stopp, Fehler, fehlendem IDR oder
veraltetem Strom geht die Zuständigkeit sofort an den Werkspfad zurück.

## Zielsperre

Der Paketbauer prüft die Originalfirmware und jede geänderte Komponente gegen die Zielbeschreibung in `targets/`
(zum Beispiel `MST2_EU_VW_P0879D.json`). Zur Laufzeit prüfen die Hooks Bibliotheksadressen und Funktionsanfänge, bevor
sie Prozessspeicher ändern. Eine Abweichung ist ein harter Stopp. Der Installer prüft die Dateien auf dem Gerät anhand
der Werte aus `stage.conf`, die aus derselben Zielbeschreibung erzeugt wird.

## Geänderte Dateien

Der Installer sichert und ersetzt:

- `/extbin/apps/cfg/iap2.cfg`
- `/extbin/apps/hmi/HMI/runHMI.sh` (nur eine Zeile im Boot-Klassenpfad; eine bekannte Community-Variante bleibt erhalten)
- `/extbin/apps/hmi/HMI/config/bundles.properties`
- `/etc/procman_core.cfg`

Die Nutzlast liegt unter `/extbin/apps/mst2-eu-carplay-maps`. Der Deinstaller stellt die vier Originale wieder her
und entfernt die Nutzlast.

---

# Architecture

The beta adds two independent CarPlay paths to the stock software of the target (`MST2_EU_VW_P0879D`).

## Route guidance

```text
iPhone RGI messages
  -> stock mm-ipod transport
  -> bounded RGI decoder and session cache
  -> shared state file
  -> late-load HMI bundle on the ASL thread
  -> stock NavBAP and ClusterServices APIs
  -> Virtual Cockpit guidance
```

The iAP2 preload registers only message group `0x52` after confirming the exact
tables of the target are unchanged. Unknown messages remain stock-owned. Malformed or
stale input clears the custom state without replacing the stock dispatcher.

## Secondary map video

```text
iPhone AirPlay stream 111
  -> target-locked libAirPlay hooks
  -> continuous AES-CTR and Screen packet parser
  -> AVCC-to-Annex-B conversion and IDR gate
  -> latest-frame shared-memory slot
  -> NavigationServer MPEG-TS worker
  -> /dev/transport_server/spawn/isoTX
  -> MOST GfxStreamSink
  -> Virtual Cockpit map
```

The receiver advertises a 1010×376 auxiliary display (244×91 mm, taken over from the original; the target's cluster is an AID 1 with 12.3 inch and 1440×540 pixels – fit not verified in a vehicle, see README). The transport candidate
uses H.264 PID `0x11`, PMT PID `0x1000`, source-derived PTS, PCR, and 64-packet
writes. Stock NavigationServer output is suppressed only after the first full
custom block succeeds. A stop, error, missing IDR, or stale stream immediately
returns ownership to the factory path.

## Target locking

The package builder verifies the stock firmware and every modified component
against the target description in `targets/` (for example `MST2_EU_VW_P0879D.json`). Runtime hooks also verify library
addresses and instruction prologues before changing process memory. A mismatch
is a hard stop.

## Modified runtime files

The installer backs up and replaces:

- `/extbin/apps/cfg/iap2.cfg`
- `/extbin/apps/hmi/HMI/runHMI.sh`
- `/extbin/apps/hmi/HMI/config/bundles.properties`
- `/etc/procman_core.cfg`

Payloads are installed under `/extbin/apps/mst2-eu-carplay-maps`. The
uninstaller restores the four originals and removes the payload.
