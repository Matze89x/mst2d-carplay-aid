# Firmware-Abgleich für `MST2_EU_VW_P0879D`

**Deutsch zuerst – English version below: [English](#english).**

> **Nur für `MST2_EU_VW_P0879D`.** Alle Werte unten gehören zu genau diesem Software-Stand (Zug `MST2_EU_VW_P0879D`, MU `0879`,
> Variante `STD2Nav_EU_VW`). Andere Züge – auch andere EU-Züge – sind nicht abgedeckt, und der Installer lehnt sie ab.
> **Nicht für Nordamerika (US/NAR) gedacht** – dafür das Original-Repository verwenden: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.

## Was verglichen wurde

Die Zielbeschreibung [`targets/MST2_EU_VW_P0879D.json`](../targets/MST2_EU_VW_P0879D.json) wurde aus dem originalen
Firmwarepaket erzeugt und danach auf zwei unabhängigen Wegen gegen die Firmwaredateien geprüft:

1. **Offizieller Weg:** `tools/analyze-firmware.cjs` liest die Originaldatei `EXTBIN_APPS.bin` (2355 Einträge) ohne etwas
   zu entpacken oder auszuführen; `tools/verify-target.cjs` vergleicht den Bericht mit der Zielbeschreibung →
   **14 Pflichtdateien, 0 Fehler.**
2. **Feste Adressen:** `tools/verify-static-bindings.cjs` liest die entpackte Firmware und prüft **18 Werte**, auf die sich
   die Hooks verlassen → **18 von 18 bestanden.** Geprüft werden im iAP2-Treiber `ipod_module`, `packet_addparam_blob`,
   `ident_info_funcs`, `iap2_ctrl_msg_table`, der GPS-Slot (Wort 0 = `0x16`, Wort 1 = Funktionsadresse) und dass die
   Nachrichtengruppe `0x52` unbelegt ist; in `libiap2client` die rohe Sendefunktion; in `libAirPlay` alle acht
   Funktionsanfänge samt Symbol und der Schlüsselableitung; im `NavigationServer` die Transport-Funktion (genau ein
   Treffer, virtuelle Adresse `0x22b350`) und der Pfad `/dev/transport_server/spawn/isoTX`.

Zur Laufzeit prüfen die Hooks auf dem Gerät dieselben Adressen und Funktionsanfänge erneut und tun bei einer Abweichung nichts.

## Fingerabdrücke des Zielgeräts

`EXTBIN_APPS.bin` (SHA-256): `4241058e0d69dfdfaf1b0d7569b5cd42cf8db9c57037d3d6da6e3fbf91d6346c`

| Datei | Bytes | SHA-256 |
|---|---:|---|
| `lib/ipod-drvr-iap2.so` | 783.734 | `2cc1439bd71d3a394291915a8c324d87ce34e985b9be69237ed6905e64394425` |
| `lib/libiap2client.so` | 22.960 | `97854159b74cd401c5faa7e413635693bee0a8c94b6d9183abfdb9d3779004b9` |
| `lib/libAirPlay.so` | 160.384 | `ff1f00e43394c451c8578e4f7e237d0a58ebe9916a8d7b3e25e6132ff8392791` |
| `lib/libAirPlaySupport.so` | 671.036 | `464877138ba69efe1e4c0818bcdf508717a8c07d5b8d022abad2d094f0acea82` |
| `jar/dsiifc.jar` | 1.184.373 | `6a18114142295fe2bd7cf0b739f40e9ce082bbbaa272eb35e2bea02d4bf92341` |
| `cfg/iap2.cfg` | 6.886 | `8d881170f61f520d92108c75df5d07ffe494255716fd899efb7ec7c6c0b4af26` |
| `usr/bin/mm-ipod` | 51.796 | `9df103a24635cdf3a81bcb975861532b2ac8875ffeab75b814e059400d7e6b70` |
| `bin/MediaHandler` | 471.863 | `02cbb116229bfde7f349bfe575c151871bd638439ebd54bd14c7c0528683bf3b` |
| `hmi/HMI/runHMI.sh` | 12.222 | `915877546533cbac2c254e13cbd3d3f0f0fc573b44f5e55317edf4a7afbe83d1` |
| `hmi/HMI/config/bundles.properties` | 9.569 | `1a736f8df9a68c88e5492d2450c5c742910fc49fe95a110b83ef0b83be9c60ca` |
| `bin/CarPlay` | 644.087 | `7a80632c766769f1cb635d805aac3a7543d301f8bdf6d4e37c2ee71d608c54c0` |
| `bin/ClusterServices` | 694.751 | `66bce7f5966eebe7f2e8e2e64e2d7dae84c3fb5492ed3499b2d772c50108c549` |
| `bin/NavigationServer` | 4.902.196 | `0156dacc5bc15d2a8084ea73d11e1e7c0803ad54a5bc7130e24dbbeeaae621b7` |
| `bin/Most` | 1.346.199 | `e63919fc54a71b0a4fe2e550a773b38c061cd73589523c630b4b248bf6e63f94` |
| `STDF.bin` (Boot-Abbild / boot image) | 10.092.544 | `ca4f7ac7264d6fd604f8339ecbedc5793f901fe39ab61986bd89d59367512caf` |
| `procman_core.cfg` (in `STDF.bin`) | 6.444 | `8dcf305d609bda78910814e9b090e51816c0c14d09d613b80b20a6d1de3bd7cf` |

Der Installer prüft die vier Dateien, die er ändert (`iap2.cfg`, `runHMI.sh`, `bundles.properties`, `procman_core.cfg`), auf dem
Gerät mit Größe und – falls `sha256sum` vorhanden ist – SHA-256. Die übrigen Werte dienen dem Paketbau und der Prüfung der Hooks.

## Unterschiede zur Original-Firmware für Nordamerika

Zum Vergleich diente die Zielbeschreibung des Originals (`MST2_US_VW_P0867D`, aus der Git-Historie):

| Datei | Bytes (Original, US) | Bytes (EU) | Ergebnis |
|---|---:|---:|---|
| `lib/ipod-drvr-iap2.so` | 783.734 | 783.734 | identisch / identical |
| `lib/libiap2client.so` | 22.960 | 22.960 | identisch / identical |
| `lib/libAirPlay.so` | 160.384 | 160.384 | identisch / identical |
| `lib/libAirPlaySupport.so` | 671.036 | 671.036 | identisch / identical |
| `jar/dsiifc.jar` | 1.184.373 | 1.184.373 | identisch / identical |
| `cfg/iap2.cfg` | 6.886 | 6.886 | gleiche Größe, anderer Inhalt / same size, different content |
| `usr/bin/mm-ipod` | 51.796 | 51.796 | identisch / identical |
| `bin/MediaHandler` | 471.863 | 471.863 | gleiche Größe, anderer Inhalt / same size, different content |
| `hmi/HMI/runHMI.sh` | 12.225 | 12.222 | andere Größe / different size |
| `hmi/HMI/config/bundles.properties` | 9.416 | 9.569 | andere Größe / different size |
| `bin/CarPlay` | 644.087 | 644.087 | gleiche Größe, anderer Inhalt / same size, different content |
| `bin/ClusterServices` | 694.751 | 694.751 | gleiche Größe, anderer Inhalt / same size, different content |
| `bin/NavigationServer` | 4.909.124 | 4.902.196 | andere Größe / different size |
| `bin/Most` | 1.346.199 | 1.346.199 | gleiche Größe, anderer Inhalt / same size, different content |
| `STDF.bin` (Boot-Abbild / boot image) | 10.092.544 | 10.092.544 | gleiche Größe, anderer Inhalt / same size, different content |
| `procman_core.cfg` (in `STDF.bin`) | 6.408 | 6.444 | andere Größe / different size |

Folgen: Die Hook-Adressen für iAP2-Treiber und AirPlay gelten unverändert (Bibliotheken bytegleich). Der Hook-Funktionsanfang im
`NavigationServer` liegt an einer anderen Adresse (`0x22cb78` im Original, `0x22b350` hier); nach dem Quelltext wird er nur dokumentiert, der Video-Hook arbeitet über
abgefangene Systemaufrufe. `runHMI.sh`, `bundles.properties`, `iap2.cfg` und `procman_core.cfg` sind eigene EU-Stände, daher der eigene Installer-Abgleich.

## Bekannte Auffälligkeit

Die Paketbeschreibung nennt die HMI-Komponente in Version `29.319.112`, das Startskript `runHMI.sh` trägt `H29.319.115`.
Die Abweichung ist nicht geklärt und für den Abgleich ohne Folgen (alle Hashes stimmen).

## Kombi

Die Firmwaredateien verraten nicht, ob ein Kombi der 1. Generation (AID 1; 12,3 Zoll, 1440×540; bis Kalenderwoche 47/2018) oder der 2.
Generation (AID 2; 10,25 Zoll, 1280×480; ab Kalenderwoche 48/2018) angeschlossen ist; dasselbe Radio kann an beiden laufen. Dieses Projekt ist
nur für **AID 1** gedacht (Angabe des Projekteigners). Der `NavigationServer` fragt eine „cluster coding"-Zahl ab (Standardwert der Firmware
bei Unbekanntem: „800er FPK"); sie kann im System-Log erscheinen und wäre eine Gegenprüfung, ist aber nicht ausgewertet.

**Teilenummern:** Die vorgesehene Hardware (Radio `3Q0 035 864` ohne Index oder A/B/C, Kombi AID 1 `5NA 920 791` ohne Index oder A/B; Angabe des Projekteigners) kommt in den
durchsuchten Firmwaredateien nicht vor (Textsuche nach `3Q0 035 864` im Paket `MST2_EU_VW_P0879D_MU0879` samt `metainfo2.txt` und in den
entpackten Dateien, nach `5NA 920 79` in den entpackten Dateien: keine Treffer). Das Ziel wird deshalb allein an den Dateien erkannt,
nicht an Teilenummern.

## So prüfst du es selbst

```sh
node tools/analyze-firmware.cjs EXTBIN_APPS.bin bericht.json
node tools/verify-target.cjs bericht.json targets/MST2_EU_VW_P0879D.json
node tools/verify-static-bindings.cjs targets/MST2_EU_VW_P0879D.json /pfad/zu/apps.tmp
```

Auf dem Gerät selbst prüft `ksh install.sh --check` die betroffenen Dateien, ohne etwas zu ändern.

---

<a id="english"></a>

# Firmware comparison for `MST2_EU_VW_P0879D`

> **Only for `MST2_EU_VW_P0879D`.** All values below belong to exactly this software state (train `MST2_EU_VW_P0879D`, MU `0879`,
> variant `STD2Nav_EU_VW`). Other trains – including other EU trains – are not covered, and the installer refuses them.
> **Not intended for North America (US/NAR)** – use the original repository for that: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.

## What was compared

The target description [`targets/MST2_EU_VW_P0879D.json`](../targets/MST2_EU_VW_P0879D.json) was generated from the original
firmware package and then checked against the firmware files in two independent ways:

1. **Official path:** `tools/analyze-firmware.cjs` reads the original `EXTBIN_APPS.bin` (2355 entries) without extracting or
   executing anything; `tools/verify-target.cjs` compares the report with the target description →
   **14 required files, 0 errors.**
2. **Fixed addresses:** `tools/verify-static-bindings.cjs` reads the unpacked firmware and checks **18 values** the hooks rely
   on → **18 of 18 passed.** In the iAP2 driver: `ipod_module`, `packet_addparam_blob`, `ident_info_funcs`,
   `iap2_ctrl_msg_table`, the GPS slot (word 0 = `0x16`, word 1 = function address) and that message group `0x52` is unused;
   in `libiap2client` the raw send function; in `libAirPlay` all eight function prologues with their symbols and the key
   derivation; in `NavigationServer` the transport function (exactly one match, virtual address
   `0x22b350`) and the path `/dev/transport_server/spawn/isoTX`.

At runtime the hooks on the unit check the same addresses and prologues again and do nothing on a mismatch.

## Fingerprints of the target unit

`EXTBIN_APPS.bin` (SHA-256): `4241058e0d69dfdfaf1b0d7569b5cd42cf8db9c57037d3d6da6e3fbf91d6346c`

| File | Bytes | SHA-256 |
|---|---:|---|
| `lib/ipod-drvr-iap2.so` | 783.734 | `2cc1439bd71d3a394291915a8c324d87ce34e985b9be69237ed6905e64394425` |
| `lib/libiap2client.so` | 22.960 | `97854159b74cd401c5faa7e413635693bee0a8c94b6d9183abfdb9d3779004b9` |
| `lib/libAirPlay.so` | 160.384 | `ff1f00e43394c451c8578e4f7e237d0a58ebe9916a8d7b3e25e6132ff8392791` |
| `lib/libAirPlaySupport.so` | 671.036 | `464877138ba69efe1e4c0818bcdf508717a8c07d5b8d022abad2d094f0acea82` |
| `jar/dsiifc.jar` | 1.184.373 | `6a18114142295fe2bd7cf0b739f40e9ce082bbbaa272eb35e2bea02d4bf92341` |
| `cfg/iap2.cfg` | 6.886 | `8d881170f61f520d92108c75df5d07ffe494255716fd899efb7ec7c6c0b4af26` |
| `usr/bin/mm-ipod` | 51.796 | `9df103a24635cdf3a81bcb975861532b2ac8875ffeab75b814e059400d7e6b70` |
| `bin/MediaHandler` | 471.863 | `02cbb116229bfde7f349bfe575c151871bd638439ebd54bd14c7c0528683bf3b` |
| `hmi/HMI/runHMI.sh` | 12.222 | `915877546533cbac2c254e13cbd3d3f0f0fc573b44f5e55317edf4a7afbe83d1` |
| `hmi/HMI/config/bundles.properties` | 9.569 | `1a736f8df9a68c88e5492d2450c5c742910fc49fe95a110b83ef0b83be9c60ca` |
| `bin/CarPlay` | 644.087 | `7a80632c766769f1cb635d805aac3a7543d301f8bdf6d4e37c2ee71d608c54c0` |
| `bin/ClusterServices` | 694.751 | `66bce7f5966eebe7f2e8e2e64e2d7dae84c3fb5492ed3499b2d772c50108c549` |
| `bin/NavigationServer` | 4.902.196 | `0156dacc5bc15d2a8084ea73d11e1e7c0803ad54a5bc7130e24dbbeeaae621b7` |
| `bin/Most` | 1.346.199 | `e63919fc54a71b0a4fe2e550a773b38c061cd73589523c630b4b248bf6e63f94` |
| `STDF.bin` (Boot-Abbild / boot image) | 10.092.544 | `ca4f7ac7264d6fd604f8339ecbedc5793f901fe39ab61986bd89d59367512caf` |
| `procman_core.cfg` (in `STDF.bin`) | 6.444 | `8dcf305d609bda78910814e9b090e51816c0c14d09d613b80b20a6d1de3bd7cf` |

On the unit the installer checks the four files it changes (`iap2.cfg`, `runHMI.sh`, `bundles.properties`,
`procman_core.cfg`) by size and – if `sha256sum` exists – SHA-256. The other values serve package building and hook verification.

## Differences from the North American original firmware

The comparison used the target description of the original (`MST2_US_VW_P0867D`, from the git history):

| File | Bytes (original, US) | Bytes (EU) | Result |
|---|---:|---:|---|
| `lib/ipod-drvr-iap2.so` | 783.734 | 783.734 | identisch / identical |
| `lib/libiap2client.so` | 22.960 | 22.960 | identisch / identical |
| `lib/libAirPlay.so` | 160.384 | 160.384 | identisch / identical |
| `lib/libAirPlaySupport.so` | 671.036 | 671.036 | identisch / identical |
| `jar/dsiifc.jar` | 1.184.373 | 1.184.373 | identisch / identical |
| `cfg/iap2.cfg` | 6.886 | 6.886 | gleiche Größe, anderer Inhalt / same size, different content |
| `usr/bin/mm-ipod` | 51.796 | 51.796 | identisch / identical |
| `bin/MediaHandler` | 471.863 | 471.863 | gleiche Größe, anderer Inhalt / same size, different content |
| `hmi/HMI/runHMI.sh` | 12.225 | 12.222 | andere Größe / different size |
| `hmi/HMI/config/bundles.properties` | 9.416 | 9.569 | andere Größe / different size |
| `bin/CarPlay` | 644.087 | 644.087 | gleiche Größe, anderer Inhalt / same size, different content |
| `bin/ClusterServices` | 694.751 | 694.751 | gleiche Größe, anderer Inhalt / same size, different content |
| `bin/NavigationServer` | 4.909.124 | 4.902.196 | andere Größe / different size |
| `bin/Most` | 1.346.199 | 1.346.199 | gleiche Größe, anderer Inhalt / same size, different content |
| `STDF.bin` (Boot-Abbild / boot image) | 10.092.544 | 10.092.544 | gleiche Größe, anderer Inhalt / same size, different content |
| `procman_core.cfg` (in `STDF.bin`) | 6.408 | 6.444 | andere Größe / different size |

Consequences: the hook addresses for the iAP2 driver and AirPlay apply unchanged (byte-identical libraries). The hook
function prologue in `NavigationServer` sits at a different address (`0x22cb78` in the original, `0x22b350` here); according to the source it is only documented, the video hook works through
intercepted system calls. `runHMI.sh`, `bundles.properties`, `iap2.cfg` and `procman_core.cfg` are EU states of their own, hence the installer's own check.

## Known oddity

The package description names the HMI component in version `29.319.112`, while the start script `runHMI.sh` carries `H29.319.115`.
The discrepancy is unexplained and without consequence for the comparison (all hashes match).

## Cluster

The firmware files do not reveal whether a first-generation cluster (AID 1; 12.3 inch, 1440×540; up to calendar week 47/2018) or a
second-generation cluster (AID 2; 10.25 inch, 1280×480; from calendar week 48/2018) is connected; the same radio runs with both. This project
is intended for **AID 1** only (statement of the project owner). `NavigationServer` queries a "cluster coding" number (firmware default when
unknown: "800er FPK"); it may appear in the system log and would be a cross-check, but it has not been evaluated.

**Part numbers:** the intended hardware (radio `3Q0 035 864` no index or A/B/C, cluster AID 1 `5NA 920 791` no index or A/B; statement of the project owner) does not
occur in the searched firmware files (text search for `3Q0 035 864` in the package `MST2_EU_VW_P0879D_MU0879` including `metainfo2.txt`
and in the unpacked files, for `5NA 920 79` in the unpacked files: no hits). The target is therefore recognised by its files alone,
not by part numbers.

## Verify it yourself

```sh
node tools/analyze-firmware.cjs EXTBIN_APPS.bin report.json
node tools/verify-target.cjs report.json targets/MST2_EU_VW_P0879D.json
node tools/verify-static-bindings.cjs targets/MST2_EU_VW_P0879D.json /path/to/apps.tmp
```

On the unit itself `ksh install.sh --check` verifies the affected files without changing anything.
