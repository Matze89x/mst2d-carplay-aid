#!/bin/sh
# Probelauf des Installers auf einem NACHBAU des Dateibaums (kein Fahrzeug, keine echte Firmware im Repo).
# Rehearsal of the installer on a MOCK file tree (no vehicle, no firmware in this repository).
#
# Aufruf / Usage (im Linux-Container, als root / inside the Linux container, as root):
#   sh tools/rehearse-install.sh <stage-dir> <stock-apps.tmp> <stock-procman_core.cfg> [<community-runHMI.sh> [<read-only-dir>]]
#
# <stage-dir>               Ergebnis von tools/build-stage.cjs / output of tools/build-stage.cjs
# <stock-apps.tmp>          entpackte Original-Firmware (nur cfg/iap2.cfg, hmi/HMI/runHMI.sh,
#                           hmi/HMI/config/bundles.properties werden gelesen) / unpacked stock firmware
# <stock-procman_core.cfg>  Original-Prozesskonfiguration / stock process configuration
# <community-runHMI.sh>     optional: runHMI.sh einer Community-Variante (z. B. NavIgnore) / optional community variant
# <read-only-dir>           optional: ein schreibgeschuetzt eingehaengter Ordner (docker -v ...:ro), simuliert eine
#                           nicht beschreibbare SD-Karte / optional: a read-only mounted directory (docker -v ...:ro),
#                           simulates a non-writable SD card
set -u
STAGE="${1:?stage-dir}"; STOCK="${2:?stock apps.tmp}"; PROCMAN="${3:?procman_core.cfg}"; COMMUNITY="${4:-}"; RODIR="${5:-}"
SHELLS="${SHELLS:-mksh dash}"
# LIMITED=1: das Radio hat beim Start nur wenige Programme (Erkenntnis aus dem ersten Test im Radio). Alle Laeufe bekommen einen
# PATH, der NUR die zwingend benoetigten Programme enthaelt, und tools.sh haengt keine weiteren Ordner an.
# LIMITED=1: the radio has very few programs at boot (finding of the first test in a radio). All runs get a PATH that
# contains ONLY the essential programs, and tools.sh adds no further folders.
LIMITED="${LIMITED:-0}"
LIMBIN=/tmp/limbin.$$
if [ "$LIMITED" != "0" ]; then
  rm -rf "$LIMBIN"; mkdir -p "$LIMBIN"
  # LIMITED=1: genau die Programme, die das echte Radio beim Start hat (gemessen im zweiten Test); LIMITED=2: die zwingenden plus mv und sleep
  # LIMITED=1: exactly the programs the real radio has at boot (measured in the second test); LIMITED=2: the essential ones plus mv and sleep
  if [ "$LIMITED" = "2" ]; then SET="cp rm mkdir chmod ls mount grep mv sleep"; else SET="cp rm mkdir chmod ls mount grep awk touch date sync mv sleep cat ln uname find df pwd env"; fi
  for t in $SET; do ln -s "$(command -v $t)" "$LIMBIN/$t"; done
  echo "EINGESCHRAENKTE UMGEBUNG / LIMITED ENVIRONMENT: PATH=$LIMBIN ($(ls "$LIMBIN" | tr '\n' ' '))"
fi
FAILS=0
ok()   { echo "  OK     $*"; }
bad()  { echo "  FEHLER $*"; FAILS=$((FAILS + 1)); }

lim() {  # lim VAR=WERT... SHELL SKRIPT [ARGS]: im eingeschraenkten Modus mit leerem PATH starten / run with the limited PATH in limited mode
  if [ "$LIMITED" != "0" ]; then
    _e=""; while case "$1" in *=*) true;; *) false;; esac; do _e="$_e $1"; shift; done
    _sh=$(command -v "$1"); shift
    env -i PATH="$LIMBIN" MST2_NO_EXTRA_PATH=1 MST2_FORCE_EMIT="${MST2_FORCE_EMIT:-}" $_e "$_sh" "$@"
  else
    env "$@"
  fi
}
mock() {  # mock <wurzel>: Nachbau von /extbin/apps und /etc / mock of /extbin/apps and /etc
  R="$1"; rm -rf "$R"; mkdir -p "$R/apps/cfg" "$R/apps/hmi/HMI/config" "$R/etc"
  cp "$STOCK/cfg/iap2.cfg" "$R/apps/cfg/"
  cp "$STOCK/hmi/HMI/runHMI.sh" "$R/apps/hmi/HMI/runHMI.sh"
  cp "$STOCK/hmi/HMI/config/bundles.properties" "$R/apps/hmi/HMI/config/"
  cp "$PROCMAN" "$R/etc/procman_core.cfg"
}
snapshot() { ( cd "$1" && find . -type f -not -path '*.entfernt-*' | sort | xargs sha256sum ) ; }   # STRENG: alles zaehlt / STRICT: everything counts
run() {  # run <shell> <root> <sd-backup-dir> <args...>
  SH="$1"; R="$2"; SDB="$3"; shift 3
  lim APP_ROOT="$R/apps" ETC_DIR="$R/etc" SD_BACKUP_DIR="$SDB" "$SH" "$STAGE/install.sh" "$@" 2>&1
}
runun() {  # runun <shell> <root> <sd-copy-dir> [<override>]
  SH="$1"; R="$2"; SDC="$3"; OV="${4:-}"
  if [ -n "$OV" ]; then lim APP_ROOT="$R/apps" ETC_DIR="$R/etc" SD_BACKUP_DIR="$SDC" BACKUP_DIR_OVERRIDE="$OV" "$SH" "$STAGE/uninstall.sh" 2>&1
  else lim APP_ROOT="$R/apps" ETC_DIR="$R/etc" SD_BACKUP_DIR="$SDC" "$SH" "$STAGE/uninstall.sh" 2>&1; fi
}
sdbackup_ok() {  # <dir> <wurzel>: alle vier Originale auf der SD-Karte, byteidentisch zum Auslieferungszustand
  D="$1"; ST="$2"; good=1
  [ -f "$D/runHMI.variant" ] || good=0
  cmp -s "$D/iap2.cfg" "$ST/cfg/iap2.cfg" || good=0
  cmp -s "$D/runHMI.sh" "$ST/hmi/HMI/runHMI.sh" || good=0
  cmp -s "$D/bundles.properties" "$ST/hmi/HMI/config/bundles.properties" || good=0
  cmp -s "$D/procman_core.cfg" "$PROCMAN" || good=0
  [ "$good" = "1" ]
}

for SH in $SHELLS; do
  command -v "$SH" >/dev/null 2>&1 || { echo "Shell $SH nicht vorhanden / not available - uebersprungen / skipped"; continue; }
  echo "=============== Shell: $SH ==============="
  W=/tmp/rehearse.$$; rm -rf "$W"; mkdir -p "$W"; mock "$W/a"; snapshot "$W/a" > "$W/a.before"

  echo "[1] Pruefmodus --check aendert nichts und legt keine Sicherung an / check mode changes nothing and creates no backup"
  OUT=$(run "$SH" "$W/a" "$W/sd/b1" --check); echo "$OUT" | tail -3
  echo "$OUT" | grep -q "NICHTS geaendert" && ok "--check bestanden" || bad "--check"
  echo "$OUT" | grep -q "SD card is writable" && ok "SD-Schreibpruefung im Pruefmodus" || bad "keine SD-Schreibpruefung"
  [ "$(snapshot "$W/a")" = "$(cat "$W/a.before")" ] && ok "Geraet unveraendert" || bad "Geraet veraendert"
  [ ! -e "$W/sd/b1" ] && ok "kein SD-Ordner angelegt" || bad "SD-Ordner im Pruefmodus angelegt"

  echo "[2] Installation: Sicherung auf dem Geraet UND auf der SD-Karte / install: backup on the unit AND on the SD card"
  OUT=$(run "$SH" "$W/a" "$W/sd/b1"); echo "$OUT" | tail -5
  echo "$OUT" | grep -q "erfolgreich" && ok "Installation meldet Erfolg" || bad "Installation"
  grep -q "mst2-eu-rgi-hmi.jar" "$W/a/apps/hmi/HMI/runHMI.sh" && ok "Jar im Boot-Klassenpfad" || bad "Jar fehlt in runHMI.sh"
  cmp -s "$W/a/apps/hmi/HMI/runHMI.sh" "$STAGE/patched/hmi/HMI/runHMI.sh" && ok "runHMI.sh = vorbereitete Datei" || bad "runHMI.sh weicht ab"
  cmp -s "$W/a/apps/cfg/iap2.cfg" "$STAGE/patched/cfg/iap2.cfg" && ok "iap2.cfg = vorbereitete Datei" || bad "iap2.cfg weicht ab"
  cmp -s "$W/a/apps/hmi/HMI/config/bundles.properties" "$STAGE/patched/hmi/HMI/config/bundles.properties" && ok "bundles.properties = vorbereitete Datei" || bad "bundles.properties weicht ab"
  cmp -s "$W/a/etc/procman_core.cfg" "$STAGE/patched/etc/procman_core.cfg" && ok "procman_core.cfg = vorbereitete Datei" || bad "procman_core.cfg weicht ab"
  [ -f "$W/a/apps/mst2-eu-carplay-maps/.installed" ] && ok "Markierung gesetzt" || bad "Markierung fehlt"
  sdbackup_ok "$W/a/apps/mst2-eu-carplay-maps-backup" "$STOCK" && ok "Sicherung AUF DEM GERAET vollstaendig und byteidentisch zu den Originalen" || bad "Geraete-Sicherung unvollstaendig"
  if [ -f "$W/sd/b1/iap2.cfg" ] && cmp -s "$W/sd/b1/iap2.cfg" "$STOCK/cfg/iap2.cfg" && cmp -s "$W/sd/b1/runHMI.sh" "$STOCK/hmi/HMI/runHMI.sh" && cmp -s "$W/sd/b1/bundles.properties" "$STOCK/hmi/HMI/config/bundles.properties" && cmp -s "$W/sd/b1/procman_core.cfg" "$PROCMAN" && [ -f "$W/sd/b1/MANIFEST.txt" ] && [ -f "$W/sd/b1/LIESMICH.txt" ]; then ok "Sicherung AUF DER SD-KARTE vollstaendig (4 Dateien + MANIFEST + LIESMICH) und byteidentisch"; else bad "SD-Sicherung unvollstaendig"; fi

  echo "[3] zweite Installation wird abgelehnt / second install is refused"
  OUT=$(run "$SH" "$W/a" "$W/sd/b2"); echo "$OUT" | grep -q "FEHLER" && ok "abgelehnt" || bad "doppelte Installation nicht abgelehnt"
  [ ! -e "$W/sd/b2" ] && ok "dabei keine weitere SD-Sicherung angelegt" || bad "SD-Ordner bei abgelehnter Installation angelegt"

  echo "[4] Deinstallation: ALLES vom Geraet weg, Originale byteidentisch, SD-Sicherung bleibt / uninstall: everything off the unit, SD backup kept"
  OUT=$(runun "$SH" "$W/a" "$W/sd/u1"); echo "$OUT" | tail -5
  echo "$OUT" | grep -q "nichts von diesem Projekt" && ok "Deinstallation meldet: nichts zurueckgeblieben" || bad "Deinstallation"
  [ "$(snapshot "$W/a")" = "$(cat "$W/a.before")" ] && ok "Geraet exakt wie vor der Installation (auch ohne Sicherungsordner)" || bad "Geraet NICHT wie vorher"
  [ "$(find "$W/a" -name 'mst2-eu*' | wc -l | tr -d ' ')" = "0" ] && ok "kein 'mst2-eu*' mehr auf dem Geraet" || bad "Reste auf dem Geraet"
  [ -f "$W/sd/b1/iap2.cfg" ] && ok "SD-Sicherung aus der Installation bleibt erhalten" || bad "SD-Sicherung weg"
  [ -f "$W/sd/u1/iap2.cfg" ] && [ -f "$W/sd/u1/procman_core.cfg" ] && ok "zusaetzlich Kopie der Geraete-Sicherung auf der SD-Karte" || bad "keine SD-Kopie bei der Deinstallation"

  echo "[5] abweichende Datei (ein Byte mehr) wird abgelehnt, nichts geaendert, keine Sicherung / modified file is refused"
  mock "$W/b"; echo "x" >> "$W/b/apps/hmi/HMI/config/bundles.properties"; snapshot "$W/b" > "$W/b.before"
  OUT=$(run "$SH" "$W/b" "$W/sd/b3"); echo "$OUT" | grep -E "FEHLER" | head -1
  echo "$OUT" | grep -q "FEHLER" && ok "abgelehnt" || bad "veraenderte Datei nicht abgelehnt"
  [ "$(snapshot "$W/b")" = "$(cat "$W/b.before")" ] && ok "nichts geaendert" || bad "Geraet trotz Ablehnung veraendert"
  [ ! -e "$W/sd/b3" ] && ok "keine SD-Sicherung angelegt" || bad "SD-Sicherung bei Ablehnung angelegt"

  echo "[6] fehlende Nutzlast: Rueckrollen stellt Originale her, beide Sicherungen bleiben / missing payload: rollback restores, backups stay"
  mock "$W/c"; snapshot "$W/c" > "$W/c.before"
  cp -R "$STAGE" "$W/stage-broken"; rm -f "$W/stage-broken/payload/libmst2_eu_airplay.so"
  OUT=$(lim APP_ROOT="$W/c/apps" ETC_DIR="$W/c/etc" SD_BACKUP_DIR="$W/sd/b4" "$SH" "$W/stage-broken/install.sh" 2>&1); echo "$OUT" | tail -3
  echo "$OUT" | grep -q "wiederhergestellt" && ok "Rueckrollen gemeldet" || bad "kein Rueckrollen"
  [ -f "$W/c/apps/mst2-eu-carplay-maps-backup/iap2.cfg" ] && [ -f "$W/sd/b4/iap2.cfg" ] && ok "beide Sicherungen bleiben nach dem Rueckrollen erhalten" || bad "Sicherungen weg"
  rm -rf "$W/c/apps/mst2-eu-carplay-maps-backup" "$W/c/apps/mst2-eu-carplay-maps"
  [ "$(snapshot "$W/c")" = "$(cat "$W/c.before")" ] && ok "Originale nach Rueckrollen identisch" || bad "Originale nach Rueckrollen NICHT identisch"

  echo "[7] SD-Sicherungsordner existiert schon -> Abbruch vor jeder Aenderung / SD backup dir already exists -> abort"
  mock "$W/e"; snapshot "$W/e" > "$W/e.before"; mkdir -p "$W/sd/b5"
  OUT=$(run "$SH" "$W/e" "$W/sd/b5"); echo "$OUT" | grep -q "existiert schon" && ok "abgelehnt" || bad "vorhandenen SD-Ordner nicht abgelehnt"
  [ "$(snapshot "$W/e")" = "$(cat "$W/e.before")" ] && ok "Geraet unveraendert" || bad "Geraet veraendert"

  if [ -n "$RODIR" ]; then
    echo "[8] SD-Karte NICHT beschreibbar (schreibgeschuetzter Ordner) -> Abbruch vor jeder Aenderung / SD card NOT writable -> abort"
    mock "$W/f"; snapshot "$W/f" > "$W/f.before"
    OUT=$(run "$SH" "$W/f" "$RODIR/sd-backup"); echo "$OUT" | grep -E "FEHLER|ERROR" | head -2
    echo "$OUT" | grep -q "SD-Karte nicht beschreibbar" && ok "Abbruch wegen nicht beschreibbarer SD-Karte" || bad "kein Abbruch bei schreibgeschuetzter SD-Karte"
    [ "$(snapshot "$W/f")" = "$(cat "$W/f.before")" ] && ok "Geraet unveraendert, keine Sicherung angelegt" || bad "Geraet trotz Abbruch veraendert"
    OUT=$(run "$SH" "$W/f" "$RODIR/sd-backup" --check); echo "$OUT" | grep -q "SD-Karte nicht beschreibbar" && ok "auch der Pruefmodus meldet es" || bad "Pruefmodus meldet nichts"
  fi

  if [ -n "$COMMUNITY" ]; then
    echo "[9] Community-runHMI.sh (z. B. NavIgnore) bleibt erhalten / community variant is preserved"
    mock "$W/d"; cp "$COMMUNITY" "$W/d/apps/hmi/HMI/runHMI.sh"; snapshot "$W/d" > "$W/d.before"
    OUT=$(run "$SH" "$W/d" "$W/sd/b6" --check); echo "$OUT" | grep -E "variant|bestanden|FEHLER" | head -3
    OUT=$(run "$SH" "$W/d" "$W/sd/b6"); echo "$OUT" | tail -2
    grep -q "NavActiveIgnore.jar" "$W/d/apps/hmi/HMI/runHMI.sh" && ok "NavIgnore-Zeile erhalten" || bad "NavIgnore-Zeile verloren"
    grep -q "mst2-eu-rgi-hmi.jar" "$W/d/apps/hmi/HMI/runHMI.sh" && ok "Jar angehaengt" || bad "Jar fehlt"
    cmp -s "$W/sd/b6/runHMI.sh" "$COMMUNITY" && ok "SD-Sicherung enthaelt die Community-Variante byteidentisch" || bad "SD-Sicherung der Community-Variante weicht ab"
    L1=$(wc -l < "$COMMUNITY"); L2=$(wc -l < "$W/d/apps/hmi/HMI/runHMI.sh"); [ "$L1" = "$L2" ] && ok "Zeilenzahl gleich" || bad "Zeilenzahl geaendert"
    runun "$SH" "$W/d" "$W/sd/u2" > /dev/null
    [ "$(snapshot "$W/d")" = "$(cat "$W/d.before")" ] && ok "Deinstallation: Geraet exakt wie vorher (Community-Variante byteidentisch)" || bad "Community-Variante/Geraet NICHT identisch zurueck"
  fi
  echo "[10] Deinstallation ganz ohne Sicherung: Rueckbau (runHMI.sh) + eigene Kopie (STOCK_DIR), Modus rename / uninstall without any backup: jar removal + own copy, rename mode"
  mock "$W/g"; snapshot "$W/g" > "$W/g.before"
  run "$SH" "$W/g" "$W/sd/g1" > /dev/null
  rm -rf "$W/g/apps/mst2-eu-carplay-maps-backup"
  mkdir -p "$W/stockcopy"; cp "$STOCK/cfg/iap2.cfg" "$STOCK/hmi/HMI/config/bundles.properties" "$PROCMAN" "$W/stockcopy/"
  OUT=$(lim APP_ROOT="$W/g/apps" ETC_DIR="$W/g/etc" SD_BACKUP_DIR="$W/sd/g2" STOCK_DIR="$W/stockcopy" UNINSTALL_MODE=rename UNINSTALL_SUFFIX=T1 "$SH" "$STAGE/uninstall.sh" 2>&1); echo "$OUT" | tail -3
  echo "$OUT" | grep -q "UMBENANNT" && ok "Deinstallation meldet: umbenannt" || bad "Deinstallation (ohne Sicherung) fehlgeschlagen"
  [ "$(snapshot "$W/g")" = "$(cat "$W/g.before")" ] && ok "Radio exakt wie vor der Installation (ohne Sicherung)" || bad "Radio NICHT wie vorher"
  [ -d "$W/g/apps/mst2-eu-carplay-maps.entfernt-T1" ] && ok "Ordner umbenannt (.entfernt-T1), nichts geloescht" || bad "kein umbenannter Ordner"
  echo "$OUT" | grep -q "Rueckbau" && echo "$OUT" | grep -q "eigene Kopie" && ok "Quellen im Protokoll" || bad "Quellen fehlen im Protokoll"
  mock "$W/h"; snapshot "$W/h" > "$W/h.before"
  run "$SH" "$W/h" "$W/sd/h1" > /dev/null
  rm -rf "$W/h/apps/mst2-eu-carplay-maps-backup" "$W/stockcopy/iap2.cfg"
  OUT=$(lim APP_ROOT="$W/h/apps" ETC_DIR="$W/h/etc" SD_BACKUP_DIR="$W/sd/h2" STOCK_DIR="$W/stockcopy" "$SH" "$STAGE/uninstall.sh" 2>&1)
  echo "$OUT" | grep -q "keine gueltige Quelle fuer iap2.cfg" && ok "fehlende Quelle: Abbruch vor jeder Aenderung" || bad "fehlende Quelle nicht gemeldet"
  [ "$(snapshot "$W/h")" != "$(cat "$W/h.before")" ] && [ -f "$W/h/apps/mst2-eu-carplay-maps/.installed" ] && ok "Radio blieb dabei im installierten Zustand (nichts halb zurueckgebaut)" || bad "halb zurueckgebaut"
  rm -rf "$W"
done
rm -rf "$LIMBIN"
echo
if [ "$FAILS" = "0" ]; then echo "=== ALLE PROBEN BESTANDEN / ALL REHEARSALS PASSED"; exit 0; fi
echo "=== $FAILS FEHLER / FAILURES"; exit 1
