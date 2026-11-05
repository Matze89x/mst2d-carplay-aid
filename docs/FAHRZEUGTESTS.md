# Fahrzeugtests / Vehicle tests

**Deutsch zuerst – English version below: [English](#english).**

Stand: 2026-11-05. Alle Angaben stammen aus Protokollen von Radios, die beim Test auf die SD-Karte geschrieben wurden. Ohne Seriennummern, ohne Fahrgestellnummer.

## Zusammenfassung

| | Test 1 (Beta 4) | Test 2 (Beta 6) |
|---|---|---|
| Fahrzeug | Tester, Radio `3Q0 035 874 C`, Kombi `3G0 920 791 B` (Angabe des Testers) | Fahrzeug des Projekteigners |
| Prüfung (Dateigrößen, Variante `runHMI.sh`) | bestanden (Standardvariante) | bestanden (NavIgnore-Variante des Radios) |
| Installation (Sicherung auf Radio **und** SD-Karte) | grün, Dateien wie erwartet | grün, Dateien wie erwartet |
| Radio startet danach | ja, **aber** Navigationsprogramm stürzte beim Start ab (`run fault … signal 11 … ip 0`) | ja, **kein** Absturz im Start (ein Lauf) |
| iPhone per Kabel anschließen | Radio fällt nach kurzer Zeit aus, danach blauer „EMERGENCY UPDATE"-Bildschirm | Radio fällt nach etwa 1,5 Minuten aus, danach blauer „EMERGENCY UPDATE"-Bildschirm |
| CarPlay / Karte im Kombi | nicht erschienen | nicht erschienen |
| Deinstallation | grün; Originale byteidentisch zurück (Sicherung auf Radio = Sicherung auf Karte) | grün; Nachkontrolle bestanden (alle vier Dateien Original, nichts von diesem Projekt mehr in `/extbin/apps`); die NavIgnore-`runHMI.sh` kam byteidentisch zurück; alles Entfernte lag vorher als Kopie auf der Karte |
| Radio danach | nach Neustart wieder normal | nach Neustart wieder normal |

## Was Test 2 im Protokoll zeigt (Dauer-Logger, alle 5 s)

1. Start mit installierter Version: **kein** `run fault`, keine Absturzdatei. Der in Test 1 gefundene Absturz im `NavigationServer` (falsche `RTLD_*`-Werte, siehe `docs/AENDERUNGEN.md`, Beta 5) trat nicht mehr auf. Ein Lauf ist kein Beweis.
2. Etwa 3:35 Minuten nach dem Start: iPhone angeschlossen. `mm-ipod`, `io-usb-dcd` und `mdnsd` starten, unser Hook meldet „EU RGI component offered". `CarPlay` und `NavigationServer` laufen mit unveränderten Prozessnummern weiter.
3. Etwa 1:30 Minuten später: `mm-ipod`, `io-usb-dcd` und `mdnsd` sind wieder weg, der USB-Treiber `io-usb` startet neu.
4. Etwa 40 Sekunden danach hört das Protokoll auf zu schreiben: das Radio ist ausgegangen oder hat sich zurückgesetzt. Es gibt keine Absturzdatei.

## Was wir **nicht** wissen

- Warum das Radio ausgeht. Das Protokoll des iPhone-Teils (`/dev/shmem/iap2.log`, etwa 148 KB) liegt im Arbeitsspeicher und war nach dem Neustart weg; der Logger sicherte es damals nicht (inzwischen behoben).
- Welcher unserer Teile den Fehler auslöst: die geänderte iAP2-Meldung (`libmst2_eu_ipod.so` mit `iap2.cfg`), der Start von `mm-ipod` (`libmst2_eu_launch.so` im MediaHandler) oder die CarPlay-Hooks (`libmst2_eu_airplay.so`). Der Fehler tritt mit dem Weg der iPhone-Verbindung auf; ohne iPhone lief das Radio stabil.
- Ob der Notfall-Update-Bildschirm auch dauerhaft stehen bleiben kann. In beiden Tests war das Radio nach einem Neustart wieder normal. Der Bootloader war jeweils intakt.
- Ob es ohne unsere Änderungen mit demselben Kabel und Telefon funktioniert. Das ist zu prüfen (Original-Zustand mit demselben iPhone).

## Nächste Schritte

1. Die Bibliotheken **einzeln** zuschalten (NavigationServer-Teil, dann MediaHandler-Teil, dann CarPlay-Teil), auf dem Tisch, mit Dauer-Logger.
2. Das iPhone-Protokoll mitsichern (`iap2.log`).
3. Erst nach einem Lauf mit angeschlossenem iPhone ohne Ausfall wieder Fahrzeugtests empfehlen.

## Fehler in unseren Werkzeugen, die die Tests aufgedeckt haben (behoben)

| Fehler | Folge | Behoben |
|---|---|---|
| Der Installer nutzte `dirname`, `cksum`, `id`, `tail`, `uptime`, `expr`, die dem Radio beim SD-Start fehlen | Abbruch vor jeder Änderung (rotes Bild) | Beta 2 (`installer/tools.sh`) |
| Die Vorabprüfung verlangte `rmdir` als zwingend | Abbruch vor jeder Änderung | Beta 3 |
| `RTLD_DEFAULT`/`RTLD_NEXT` waren 0/-1 statt -2/-3, Ergebnis von `dlsym` ohne Prüfung aufgerufen | Absturz des `NavigationServer` beim Start | Beta 5 (`include/dcc_resolve.h`) |
| Das Radio blendet nach dem SD-Skript selbst ein grünes Statusbild ein, das stehen bleibt | Bei dauerhaft steckender Karte war das Radio verdeckt | Beta 6 (Bild wird im Protokoll-Betrieb nach 10 s entfernt) |
| Der Logger sicherte `/dev/shmem/iap2.log` nicht | Die Ursache des Ausfalls beim iPhone-Anschluss ist nicht belegbar | Beta 6 (sichert alle `*.log` und `*.txt` im Arbeitsspeicher) |
| `sloginfo` zeigt nur die ersten etwa 80 Zeilen (Start) | Spätere Ereignisse stehen nicht im Systemlog | festgestellt; der Logger nutzt zusätzlich Prozessliste und `iap2.log` |

---

<a id="english"></a>

# Vehicle tests (English)

Status: 2026-11-05. All statements come from logs that the radios wrote to the SD card during the tests. No serial numbers, no VIN.

## Summary

| | Test 1 (beta 4) | Test 2 (beta 6) |
|---|---|---|
| Vehicle | Tester, radio `3Q0 035 874 C`, cluster `3G0 920 791 B` (as reported by the tester) | Vehicle of the project owner |
| Check (file sizes, `runHMI.sh` variant) | passed (standard variant) | passed (the radio's NavIgnore variant) |
| Installation (backup on the radio **and** SD card) | green, files as expected | green, files as expected |
| Radio starts afterwards | yes, **but** the navigation program crashed at startup (`run fault … signal 11 … ip 0`) | yes, **no** crash at startup (one run) |
| Connect iPhone by cable | the radio drops out after a short time, then the blue "EMERGENCY UPDATE" screen | the radio drops out after about 1.5 minutes, then the blue "EMERGENCY UPDATE" screen |
| CarPlay / map in the cluster | did not appear | did not appear |
| Uninstall | green; originals back byte for byte (backup on the radio = backup on the card) | green; final check passed (all four files stock, nothing of this project left in `/extbin/apps`); the NavIgnore `runHMI.sh` came back byte for byte; everything removed was copied to the card first |
| Radio afterwards | normal again after a restart | normal again after a restart |

## What test 2 shows in the log (permanent logger, every 5 s)

1. Start with the installed version: **no** `run fault`, no crash file. The `NavigationServer` crash found in test 1 (wrong `RTLD_*` values, see `docs/AENDERUNGEN.md`, beta 5) did not occur again. One run is not proof.
2. About 3:35 minutes after the start: iPhone connected. `mm-ipod`, `io-usb-dcd` and `mdnsd` start, our hook reports "EU RGI component offered". `CarPlay` and `NavigationServer` keep running with unchanged process numbers.
3. About 1:30 minutes later: `mm-ipod`, `io-usb-dcd` and `mdnsd` are gone again, the USB driver `io-usb` restarts.
4. About 40 seconds later the log stops: the radio switched off or reset. There is no crash file.

## What we do **not** know

- Why the radio drops out. The log of the iPhone part (`/dev/shmem/iap2.log`, about 148 KB) lives in RAM and was gone after the restart; the logger did not save it then (fixed since).
- Which of our parts triggers it: the changed iAP2 message (`libmst2_eu_ipod.so` with `iap2.cfg`), the start of `mm-ipod` (`libmst2_eu_launch.so` in the MediaHandler) or the CarPlay hooks (`libmst2_eu_airplay.so`). The failure appears on the iPhone connection path; without an iPhone the radio ran stable.
- Whether the emergency-update screen can also stay permanently. In both tests the radio was normal again after a restart. The bootloader was intact each time.
- Whether it works without our changes with the same cable and phone. This still has to be checked (stock state with the same iPhone).

## Next steps

1. Enable the libraries **one at a time** (NavigationServer part, then MediaHandler part, then CarPlay part), on a bench, with the permanent logger.
2. Save the iPhone log as well (`iap2.log`).
3. Recommend vehicle tests again only after a run with a connected iPhone without a drop-out.

## Errors in our own tools that the tests uncovered (fixed)

| Error | Consequence | Fixed |
|---|---|---|
| The installer used `dirname`, `cksum`, `id`, `tail`, `uptime`, `expr`, which the radio lacks when the SD script runs | abort before any change (red screen) | beta 2 (`installer/tools.sh`) |
| The up-front check required `rmdir` | abort before any change | beta 3 |
| `RTLD_DEFAULT`/`RTLD_NEXT` were 0/-1 instead of -2/-3, the `dlsym` result was called unchecked | `NavigationServer` crash at startup | beta 5 (`include/dcc_resolve.h`) |
| After the SD script the radio itself shows a green status image that stays | with the card left in, the radio was covered | beta 6 (image removed after 10 s in log mode) |
| The logger did not save `/dev/shmem/iap2.log` | the cause of the drop-out on iPhone connection cannot be shown | beta 6 (saves all `*.log` and `*.txt` in RAM) |
| `sloginfo` shows only the first ~80 lines (startup) | later events are not in the system log | noted; the logger additionally uses the process list and `iap2.log` |
