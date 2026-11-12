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

## Neu in beta.7: mögliche Ursache des Aussetzens, Schutz eingebaut (noch nicht im Auto geprüft)

Beim Lesen des Treibers `ipod-drvr-iap2.so` (P0879D) und eines verwandten Projekts (TechniSat/Preh, `perkthefox/mst2-cluster-nav`) ist uns eine plausible Erklärung aufgefallen. Statisch belegt (Disassemblierung):

- In `link_handle_payload` (0x169b0) zählt der Treiber bei jeder **IdentificationRejected**-Meldung einen Zähler bei `Gerät+0xb0` hoch. Ab der **7. Ablehnung** schreibt er ins Log und ruft `exit(-1)` auf. `mm-ipod` beendet sich dann. Der Zähler wird nirgends zurückgesetzt.
- `ident_info_reject_recv` (0x10d68) kennt nur die Parameter-IDs 6 bis 24. Wird unsere zusätzliche Komponente (Gruppe 30) abgelehnt, schaltet der Treiber sie **nicht** ab, sie wird bei jeder Wiederholung erneut angeboten.

**Nicht belegt:** ob das iPhone die Komponente wirklich ablehnt, und ob das das Aussetzen nach rund 1,5 Minuten erklärt. In den bisherigen Protokollen steht nur „EU RGI component offered“; `iap2.log` liegt im RAM und ist nach dem Neustart weg.

**Schutz:** Der Hook liest den Zähler und bietet die Komponente nur an, solange er 0 ist. Sein Log (`/dev/shmem/mst2-eu-rgi.log`) wird jetzt fortgeschrieben und nennt den Zählerstand („rejections so far: N“). Ein Logiktest mit nachgebauten Treiberfunktionen (`native/delphi-qnx/host_test.sh`) prüft das Verhalten; er sagt nichts darüber, was ein echtes iPhone oder der echte Treiber tut.

## Neu in beta.8: Start-Nachricht 0x5200 wird gesendet (noch nicht im Auto geprüft)

Der Vergleich mit dem TechniSat-Projekt `perkthefox/mst2-cluster-nav` zeigte eine Lücke: Das iPhone sendet Routendaten (0x5201/0x5202/0x5204) erst, **nachdem das Auto `StartRouteGuidanceUpdate` (0x5200) geschickt hat**. Bis beta.7 wurde diese Nachricht zwar gebaut, aber nie gesendet; der Delphi-Treiber sendet sie von selbst nicht.

- Neu: `libmst2_eu_airplay.so` (läuft im Prozess `CarPlay`) startet einen Sender. Er nutzt `libiap2client.so.1` (`iap2_connect`, `iap2_raw_msg_send`, `iap2_disconnect`, im `CarPlay`-Prozess schon geladen) und sendet einen 12-Byte-Rahmen an `/dev/ipod0`. Das ist der Pfad aus der Firmware; dass genau diese Zeichenkette an den Aufrufstellen übergeben wird, ist nicht bis zur Adresse aufgelöst.
- Er sendet nur, wenn der iPhone-Hook die Komponente angeboten hat (`/dev/shmem/mst2-eu-rgi-ready` = `offered`; nach einer Ablehnung `omitted`, vor der ersten Identifikation `pending`), alle 2 s zehnmal, danach alle 30 s, und hört auf, sobald die erste Routen-Nachricht im `iap2.log` steht (Marke `/dev/shmem/mst2-eu-rgi-seen` = `1`). Eine Datei `/dev/shmem/mst2-eu-rgi-nosend` schaltet ihn ab.
- Wirksam in den Bisect-Stufen mit `m` **und** `c` (`nmc`); ohne `m` wird die Komponente nie angeboten, dann wird nichts gesendet.
- Geprüft nur mit nachgebauten Funktionen (`native/delphi-qnx/host_test.sh`): Zeitpunkt, Rahmen, Wiederholung, Abbruch. Was ein echtes iPhone, `mm-ipod` oder die echte `libiap2client.so` tun, ist offen. Es ist möglich, dass das Senden das Verhalten beim Anschluss ändert; darum bleibt die Stufenfolge des Bisect-Tests.
- Im Auto zu lesen: Hook-Log (`0x5200 sent …` oder eine Fehlerzeile), Marke `…-seen`, im `iap2.log` Treffer `msgid=5201`.

## Neu in beta.9: AirPlay-Beschreibung der zweiten Anzeige als „Schema B", schaltbar (noch nicht im Auto geprüft)

Der Vergleich mit `perkthefox/mst2-cluster-nav` zeigte, dass unsere `/info`-Antwort an das iPhone anders aufgebaut ist als bei dem Projekt, das auf demselben AirPlay-Plug-in (SDK 210.81) im Auto lief: dort `extendedFeatures` (bei uns `enabledFeatures`), zusätzlich `displayPanels`, und die Hauptanzeige bekommt `uid` und `initialVideoStreams`.

- Standard bleibt **Schema A** (wie bisher). **Schema B** wird nur eingeschaltet, wenn die RAM-Datei `/dev/shmem/mst2-eu-rgi-infoschema` mit `b` beginnt. Sie wird bei jedem `/info` und SETUP gelesen; ohne Datei gilt wieder Schema A.
- Schema B: `/info` mit `extendedFeatures` = `altScreen`, `viewAreas`; `displays` und `displayPanels` mit Hauptanzeige (alle Stock-Schlüssel plus `uid`, `initialVideoStreams`) und Kombi-Anzeige (ohne `type`, mit `properties`, `drawUIOutsideSafeArea`, `maxFPS` 25); `enabledFeatures` in der SETUP-Antwort nur beim ersten Steuer-SETUP. Gibt es nicht genau eine Stock-Anzeige mit `uuid`, bleibt `/info` unverändert.
- Der sichere Bereich (Safe Area) und die Maße sind unsere bisherigen Werte, nicht die von perkthefox; sie hängen vom Kombi ab.
- Einschalten: Bisect-Stufe `nmcb` (nach `nmc`, setzt die Datei in dem Start, in dem sie aktiv ist, `MODUS.txt` zeigt `nmcb`) oder per Telnet `schalter.sh info-b` (ohne Neustart, ab der nächsten iPhone-Verbindung; `info-a` schaltet zurück).
- Geprüft nur mit einem nachgebauten Core Foundation (`native/delphi-qnx/host_test.sh`): Form des Wörterbuchs, Schutz bei unerwarteter Eingabe. Ob das iPhone Schema B annimmt und Stream 111 anfordert, ist offen; bei perkthefox selbst fordert es ihn bei einem Anwender trotz dieses Schemas nicht an (Issue 2). Eine falsche `/info`-Antwort könnte auch das normale CarPlay-Bild stören; darum ist es nur die letzte Stufe.

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

## New in beta.7: a possible cause of the drop-out, guard added (not yet checked in a car)

Reading the driver `ipod-drvr-iap2.so` (P0879D) and a related project (TechniSat/Preh, `perkthefox/mst2-cluster-nav`) suggested a plausible explanation. Established statically (disassembly):

- In `link_handle_payload` (0x169b0) the driver increments a counter at `device+0xb0` on every **IdentificationRejected** message. From the **7th rejection** on it logs and calls `exit(-1)`, so `mm-ipod` quits. The counter is never reset.
- `ident_info_reject_recv` (0x10d68) knows only parameter IDs 6 to 24. If our extra component (group 30) is rejected, the driver does **not** switch it off, and it is offered again on every repeat.

**Not established:** whether the iPhone really rejects the component, and whether that explains the drop-out after about 1.5 minutes. The logs so far only say "EU RGI component offered"; `iap2.log` lives in RAM and is gone after the restart.

**Guard:** the hook reads the counter and offers the component only while it is 0. Its log (`/dev/shmem/mst2-eu-rgi.log`) is now appended to and names the counter ("rejections so far: N"). A logic test with faked driver functions (`native/delphi-qnx/host_test.sh`) checks the behaviour; it says nothing about what a real iPhone or the real driver does.

## New in beta.8: the start message 0x5200 is now sent (not yet checked in a car)

The comparison with the TechniSat project `perkthefox/mst2-cluster-nav` showed a gap: the iPhone sends route guidance (0x5201/0x5202/0x5204) only **after the car has sent `StartRouteGuidanceUpdate` (0x5200)**. Up to beta.7 the message was built but never sent; the Delphi driver does not send it by itself.

- New: `libmst2_eu_airplay.so` (runs in the `CarPlay` process) starts a sender. It uses `libiap2client.so.1` (`iap2_connect`, `iap2_raw_msg_send`, `iap2_disconnect`, already loaded in `CarPlay`) and sends a 12-byte frame to `/dev/ipod0`. That is the path from the firmware; that exactly this string is passed at the call sites was not resolved down to the address.
- It sends only when the iPhone hook offered its component (`/dev/shmem/mst2-eu-rgi-ready` = `offered`; `omitted` after a rejection, `pending` before the first identification), ten times every 2 s and then every 30 s, and stops once the first route message appears in `iap2.log` (mark `/dev/shmem/mst2-eu-rgi-seen` = `1`). A file `/dev/shmem/mst2-eu-rgi-nosend` switches it off.
- Active in the bisect stages with `m` **and** `c` (`nmc`); without `m` the component is never offered, so nothing is sent.
- Checked only with faked functions (`native/delphi-qnx/host_test.sh`): timing, frame, retry, stop. What a real iPhone, `mm-ipod` or the real `libiap2client.so` do is open. Sending may change the behaviour on connect, which is why the staged bisect order stays.
- To read in the car: hook log (`0x5200 sent …` or an error line), the `…-seen` mark, hits for `msgid=5201` in `iap2.log`.

## New in beta.9: AirPlay description of the second display as "schema B", switchable (not yet checked in a car)

The comparison with `perkthefox/mst2-cluster-nav` showed that our `/info` answer to the iPhone is built differently from the project that ran on the same AirPlay plug-in (SDK 210.81) in a car: there `extendedFeatures` (ours: `enabledFeatures`), plus `displayPanels`, and the main display gets `uid` and `initialVideoStreams`.

- The default stays **schema A** (as before). **Schema B** is switched on only when the RAM file `/dev/shmem/mst2-eu-rgi-infoschema` starts with `b`. It is read at every `/info` and SETUP; without the file schema A applies again.
- Schema B: `/info` with `extendedFeatures` = `altScreen`, `viewAreas`; `displays` and `displayPanels` with the main display (all stock keys plus `uid`, `initialVideoStreams`) and the cluster display (no `type`, with `properties`, `drawUIOutsideSafeArea`, `maxFPS` 25); `enabledFeatures` in the SETUP answer only on the first control SETUP. If there is not exactly one stock display with a `uuid`, `/info` is left unchanged.
- The safe area and sizes are our previous values, not perkthefox's; they depend on the cluster.
- Switch on: bisect stage `nmcb` (after `nmc`, sets the file in the start where it is active, `MODUS.txt` shows `nmcb`) or over Telnet `schalter.sh info-b` (no restart, from the next iPhone connection; `info-a` switches back).
- Checked only with a faked Core Foundation (`native/delphi-qnx/host_test.sh`): shape of the dictionary, guards against unexpected input. Whether the iPhone accepts schema B and requests stream 111 is open; with perkthefox itself one user's iPhone does not request it despite this schema (issue 2). A wrong `/info` answer could also disturb the normal CarPlay picture, which is why it is only the last stage.

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
