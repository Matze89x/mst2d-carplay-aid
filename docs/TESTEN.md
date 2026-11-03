# Freiwillige Tester gesucht

**Deutsch zuerst – English version below: [English](#english).**

> **Wichtig: Dieses Projekt ist nur für das Gerät `MST2_EU_VW_P0879D` (EU) bestimmt und am Fahrzeug erst teilweise geprüft (Beta 4: Installation und Deinstallation sauber, aber Absturz des Navigationsprogramms; die Korrektur in Beta 5 ist ungeprüft).**
> Wer es ausprobiert, tut das auf eigene Gefahr; es kann zu einer Boot-Schleife führen. Für US-Geräte (`MST2_US_VW_P0867D`)
> bitte das Original verwenden: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.

Wir freuen uns über **freiwillige Tester mit genau diesem Gerät**. Ohne Tests am Fahrzeug bleibt alles hier ein Entwurf.

## Voraussetzungen

1. Gerät mit Zug **exakt** `MST2_EU_VW_P0879D` und MU `0879` (Versionsanzeige prüfen). Andere Züge – auch andere EU-Züge –
   werden vom Installer abgelehnt. **Zusätzlich muss das Kombi ein Active Info Display der 1. Generation (AID 1) sein**: 12,3 Zoll, 1440×540 Pixel, verbaut bis Kalenderwoche 47/2018.
   **Nicht geeignet:** AID 2 / „Digital Cockpit Pro" (10,25 Zoll, 1280×480, ab Kalenderwoche 48/2018 und Facelift). Das kann der Installer nicht prüfen.
   Vorgesehen sind das Radio mit der Teilenummer **3Q0 035 864** (ohne Index-Buchstabe oder A, B, C) und das Kombi **AID 1 5NA 920 791** (ohne Index-Buchstabe oder A, B); die Index-Buchstaben sind eine Annahme des Projekteigners und nicht geprüft – bitte deine in der Meldung angeben.
2. **Bereits funktionierender Root-Zugang** (serielle Konsole oder Telnet) und ein **vorher erprobter Wiederherstellungsweg**.
   Dieses Projekt liefert weder Freischaltung noch Firmware.
3. Beschreibbare FAT32-SD-Karte (der Installer bricht ab, wenn sie nicht beschreibbar ist), stabile Stromversorgung, Fahrzeug im Stand.
4. Eine eigene Sicherung der Originalsoftware.

## Ablauf

1. Prüfen, ohne etwas zu ändern: `ksh install.sh --check` (meldet auch, ob die SD-Karte beschreibbar ist).
2. Installieren: `ksh install.sh`. Der Installer sichert jede geänderte Datei auf dem Gerät **und** auf der SD-Karte und stellt
   bei einem Fehler die Originale selbst wieder her. Erst nach der Meldung „Installation erfolgreich abgeschlossen" neu starten.
3. Testen (nur im Stand): Gerät startet normal? Radio/Medien weiterhin in Ordnung? iPhone anschließen, CarPlay starten,
   Navigation starten: erscheinen Pfeile, Distanz, Straße, Ankunftszeit und Spuren im Kombi? Ändert sich die Kartenansicht
   im Kombi? Navigation beenden und iPhone trennen: kommt die Werkskarte zurück? Wiederverbinden und einen Zündungswechsel wiederholen.
4. Deinstallieren: `ksh uninstall.sh` – entfernt alles vom Gerät; die Sicherungen auf der SD-Karte bleiben.

## Was wir wissen möchten (bitte genau)

**Wenn etwas schiefgeht: Wir brauchen die Logs!** Nichts löschen, nichts aufräumen. Bei der SD-Karten-Version den ganzen Ordner
`mst2d-carplay-aid/sd_lauf<Nr>_<Kennung>/` sichern (Protokoll, Ablaufspur, Zustand vorher/nachher, Siegel, Sicherungen), beim Installer von Hand
die komplette Ausgabe. Kurz beschreiben, was du gemacht hast und was passiert ist. Ohne Logs können wir den Fehler nicht finden.

- Fahrzeug, Baujahr, Kombi-Generation (AID 1: 12,3″/1440×540 oder AID 2: 10,25″/1280×480), Teilenummern von Radio und Kombi (mit Index-Buchstaben), Zug und MU. Keine Seriennummern, keine Fahrgestellnummer.
- Ein Foto des Kombis bei laufender Navigation (Lage, Größe und Schärfe des Kartenfensters; Schriftgrößen).
- iPhone-Modell, iOS-Version, Karten-App.
- Ergebnis für: Start, Führung im Kombi, Karte, Trennen, Wiederverbinden, Zündungswechsel.
- Ob die Deinstallation alles zurückgesetzt hat.
- Logs (siehe oben) **ohne persönliche Daten** (zum Beispiel `sloginfo > /pfad/zur/karte/mst2-eu-carplay-maps.log`).

Teilweise Erfolge bitte genau melden: Pfeile ohne Karte, schwarze Karte, ein eingefrorenes Bild, ein Verbindungsabbruch oder
eine Boot-Schleife bezeichnen jeweils eine andere noch offene Grenze.

---

<a id="english"></a>

# Volunteer testers wanted

> **Important: this project is intended only for the unit `MST2_EU_VW_P0879D` (EU) and has only been partly verified in a vehicle (beta 4: installation and uninstall clean, but the navigation program crashed; the fix in beta 5 is unverified).**
> Anyone trying it does so at their own risk; it can cause a boot loop. For US units (`MST2_US_VW_P0867D`) please use the
> original: <https://github.com/tehfalcon-vw/mst2-nar-carplay-maps>.

We welcome **volunteer testers with exactly this unit**. Without tests in a vehicle everything here remains a draft.

## Requirements

1. A unit with the train **exactly** `MST2_EU_VW_P0879D` and MU `0879` (check the version screen). Other trains – including
   other EU trains – are refused by the installer. **In addition the cluster must be a first-generation Active Info Display (AID 1)**: 12.3 inch, 1440×540 pixels, fitted up to calendar week 47/2018.
   **Not suitable:** AID 2 / "Digital Cockpit Pro" (10.25 inch, 1280×480, from calendar week 48/2018 and facelift). The installer cannot check this.
   Intended are the radio with part number **3Q0 035 864** (no index letter, or A, B, C) and the cluster **AID 1 5NA 920 791** (no index letter, or A, B); the index letters are an assumption of the project owner and not verified – please state yours in the report.
2. An **already working root shell** (serial console or Telnet) and a **recovery method you tried beforehand**. This project
   provides neither an unlock nor firmware.
3. A writable FAT32 SD card (the installer aborts if it is not writable), stable power, vehicle parked.
4. Your own backup of the original software.

## Procedure

1. Check without changing anything: `ksh install.sh --check` (also reports whether the SD card is writable).
2. Install: `ksh install.sh`. The installer backs up every changed file on the unit **and** on the SD card and restores the
   originals itself on error. Reboot only after "Installation completed successfully".
3. Test (parked only): does the unit start normally? Are radio/media still fine? Connect an iPhone, start CarPlay, start
   navigation: do arrows, distance, street, arrival time and lanes appear in the cluster? Does the cluster map change? End
   navigation and disconnect the iPhone: does the factory map return? Repeat reconnect and one ignition cycle.
4. Uninstall: `ksh uninstall.sh` – removes everything from the unit; the backups on the SD card stay.

## What we would like to know (please be precise)

**If anything goes wrong: we need the logs!** Do not delete or tidy up anything. With the SD card version save the whole folder
`mst2d-carplay-aid/sd_lauf<no>_<ID>/` (log, trace, state before/after, seal, backups); with the installer run by hand, the complete output.
Briefly describe what you did and what happened. Without logs we cannot find the error.

- Vehicle, model year, cluster generation (AID 1: 12.3″/1440×540 or AID 2: 10.25″/1280×480), part numbers of radio and cluster (with index letters), train and MU. No serial numbers, no VIN.
- A photo of the cluster while navigation is running (position, size and sharpness of the map window; font sizes).
- iPhone model, iOS version, map app.
- Result for: boot, guidance in the cluster, map, disconnect, reconnect, ignition cycle.
- Whether uninstall restored everything.
- Logs (see above) **without personal data** (for example `sloginfo > /path/to/card/mst2-eu-carplay-maps.log`).

Please report partial successes precisely: arrows without a map, a black map, one frozen frame, a disconnect or a boot loop
each identify a different remaining boundary.
