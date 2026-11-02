#!/bin/ksh

# MST2 CarPlay Maps - Installer (Beta). Gesteuert von stage.conf / driven by stage.conf.
# NUR fuer MST2_EU_VW_P0879D (EU) (Radio 3Q0 035 864, Index leer/A/B/C) mit Kombi AID 1 5NA 920 791 (Index leer/A/B) (12,3 Zoll, 1440x540). Nicht fuer US/Nordamerika, nicht fuer andere Zuege, nicht fuer AID 2.
# ONLY for MST2_EU_VW_P0879D (EU) (radio 3Q0 035 864, index none/A/B/C) with cluster AID 1 5NA 920 791 (index none/A/B) (12.3 inch, 1440x540). Not for US/North America, not for other trains, not for AID 2.
# Not for US/North America and not for other trains. Jedes abweichende Geraet wird abgelehnt. / Any other unit is refused.
# Aufruf / Usage:  ksh install.sh --check   (nur pruefen, nichts am Geraet aendern / verify only, change nothing on the unit)
#                  ksh install.sh           (installieren / install)
# Jede Meldung steht zuerst auf Deutsch, darunter auf Englisch. / Every message is German first, English below.
#
# Sicherungen / Backups: Jede Datei, die geaendert oder ueberschrieben wird, wird VOR der Installation
# 1. auf dem Geraet gesichert (/extbin/apps/mst2-eu-carplay-maps-backup) UND
# 2. zusaetzlich auf der SD-Karte (SD_BACKUP_DIR, Standard: sd-backup/backup-<n> neben diesem Installer).
# Ist die SD-Karte nicht beschreibbar, wird VOR jeder Aenderung abgebrochen.
# Every file that is modified or overwritten is backed up BEFORE installation 1. on the unit and 2. additionally on
# the SD card. If the SD card is not writable, the installer aborts BEFORE any change.

set -u

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
# APP_ROOT, ETC_DIR und SD_BACKUP_DIR lassen sich fuer Tests/Notfaelle umbiegen / can be redirected for tests/emergencies
APP_ROOT=${APP_ROOT:-/extbin/apps}
ETC_DIR=${ETC_DIR:-/etc}
SD_BACKUP_DIR=${SD_BACKUP_DIR:-}
INSTALL_DIR=$APP_ROOT/mst2-eu-carplay-maps
BACKUP_DIR=$APP_ROOT/mst2-eu-carplay-maps-backup
MARKER=$INSTALL_DIR/.installed
JAR_FILE=$INSTALL_DIR/mst2-eu-rgi-hmi.jar
# Pfad, der in runHMI.sh eingetragen wird: immer der echte Pfad auf dem Geraet, auch im Testlauf
# Path written into runHMI.sh: always the real path on the unit, also in rehearsals
JAR_REF=/extbin/apps/mst2-eu-carplay-maps/mst2-eu-rgi-hmi.jar
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
SD_CREATED=0
BACKUP_FILES="iap2.cfg runHMI.sh bundles.properties procman_core.cfg"

fail() {
    echo "FEHLER: $1"
    echo "  ERROR: $2"
    echo "WICHTIG: Bitte nichts loeschen - wir brauchen die Protokolle (Logs) und die Sicherungen, um den Fehler zu finden."
    echo "  IMPORTANT: Please do not delete anything - we need the logs and the backups to find the error."
    exit 1
}

bytes() {
    wc -c < "$1" | tr -d ' '
}

# expect_pair DATEI "GROESSE SHA256" NAME: Groesse immer, SHA-256 wenn sha256sum vorhanden ist
# expect_pair FILE "SIZE SHA256" NAME: size always, SHA-256 when sha256sum is available
expect_pair() {
    [ -f "$1" ] || fail "Datei fehlt: $1" "missing file: $1"
    WANT_SIZE=${2%% *}
    WANT_HASH=${2##* }
    ACTUAL=$(bytes "$1")
    [ "$ACTUAL" = "$WANT_SIZE" ] || fail "$3: unerwartete Groesse ($ACTUAL, erwartet $WANT_SIZE); das ist nicht $TARGET_TRAIN" "$3: unexpected size ($ACTUAL, expected $WANT_SIZE); this is not $TARGET_TRAIN"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL_HASH=$(sha256sum "$1" | awk '{print $1}')
        [ "$ACTUAL_HASH" = "$WANT_HASH" ] || fail "$3: unerwarteter SHA-256; das ist nicht $TARGET_TRAIN" "$3: unexpected SHA-256; this is not $TARGET_TRAIN"
    else
        echo "Hinweis: sha256sum fehlt, geprueft wird nur die Groesse ($3)."
        echo "  Note: sha256sum is missing, only the size is checked ($3)."
    fi
}

copy_checked() {
    SOURCE=$1
    DESTINATION=$2
    MODE=$3
    cp "$SOURCE" "$DESTINATION" || return 1
    chmod "$MODE" "$DESTINATION" || return 1
    cmp -s "$SOURCE" "$DESTINATION" || return 1
    return 0
}

# Ist das Ziel auf der SD-Karte beschreibbar? Prueft den naechsten vorhandenen Ordner (legt NICHTS an).
# Is the SD target writable? Checks the nearest existing directory (creates NOTHING).
sd_writable() {
    D=$1
    while [ ! -d "$D" ]; do
        [ -e "$D" ] && return 1
        P=$(dirname "$D")
        [ "$P" = "$D" ] && return 1
        D=$P
    done
    mount -uw "$D" >/dev/null 2>&1
    touch "$D/.mst2-sd-write-test" 2>/dev/null || return 1
    rm -f "${D:?}/.mst2-sd-write-test"
    return 0
}

remove_sd_partial() {
    [ "$SD_CREATED" = "1" ] || return 0
    for f in $BACKUP_FILES runHMI.variant MANIFEST.txt LIESMICH.txt; do
        rm -f "${SD_BACKUP_DIR:?}/${f:?}"
    done
    rmdir "$SD_BACKUP_DIR" 2>/dev/null
}

discard_incomplete_backup() {
    for f in $BACKUP_FILES runHMI.variant; do
        rm -f "${BACKUP_DIR:?}/${f:?}"
    done
    rmdir "$BACKUP_DIR" 2>/dev/null
    remove_sd_partial
    fail "$1; es wurde keine Live-Datei geaendert" "$1; no live files were changed"
}

rollback() {
    echo "Installation fehlgeschlagen; Originaldateien werden wiederhergestellt..."
    echo "  Install failed; restoring stock files..."
    [ -f "$BACKUP_DIR/iap2.cfg" ] && cp "$BACKUP_DIR/iap2.cfg" "$APP_ROOT/cfg/iap2.cfg"
    [ -f "$BACKUP_DIR/runHMI.sh" ] && cp "$BACKUP_DIR/runHMI.sh" "$APP_ROOT/hmi/HMI/runHMI.sh"
    [ -f "$BACKUP_DIR/bundles.properties" ] && cp "$BACKUP_DIR/bundles.properties" "$APP_ROOT/hmi/HMI/config/bundles.properties"
    [ -f "$BACKUP_DIR/procman_core.cfg" ] && cp "$BACKUP_DIR/procman_core.cfg" "$ETC_DIR/procman_core.cfg"
    chmod 644 "$APP_ROOT/cfg/iap2.cfg" "$APP_ROOT/hmi/HMI/config/bundles.properties" "$ETC_DIR/procman_core.cfg" 2>/dev/null
    chmod 755 "$APP_ROOT/hmi/HMI/runHMI.sh" 2>/dev/null
    rm -f "${INSTALL_DIR:?}/libmst2_eu_ipod.so" "${INSTALL_DIR:?}/libmst2_eu_launch.so"
    rm -f "${INSTALL_DIR:?}/libmst2_eu_video_gate.so" "${INSTALL_DIR:?}/libmst2_eu_airplay.so"
    rm -f "${INSTALL_DIR:?}/mst2-eu-rgi-hmi.jar" "${MARKER:?}"
    sync
    echo "Originaldateien wiederhergestellt. NICHT neu starten, bevor die Fehler oben verstanden sind."
    echo "  Stock files restored. Do not reboot until the errors above are understood."
    echo "Die Sicherungen bleiben erhalten: $BACKUP_DIR und $SD_BACKUP_DIR"
    echo "  The backups are kept: $BACKUP_DIR and $SD_BACKUP_DIR"
    exit 1
}

# grep ohne Zeichensatz-Probleme (Dateien koennen Fuellbytes enthalten) / grep without locale trouble (files may contain filler bytes)
g() {
    LC_ALL=C grep "$@"
}

# Haengt das HMI-Jar an die erste Zuweisung des Boot-Klassenpfads an (Original ODER Community-Patch wie NavIgnore).
# Byte-genau: nur diese eine Zeile wird ersetzt, der Rest der Datei bleibt unveraendert (auch ohne Zeilenende am Dateiende).
# Appends the HMI jar to the first boot class path assignment (stock OR community patch such as NavIgnore).
# Byte-exact: only that one line is replaced, the rest of the file stays unchanged (even without a trailing newline).
patch_hmi() {
    N=$(g -n '^BOOTCLASSPATH="/' "$1" | head -n 1 | cut -d: -f1)
    [ -n "$N" ] || return 3
    LINE=$(head -n "$N" "$1" | tail -n 1)
    case "$LINE" in
        *\") ;;
        *) return 3 ;;
    esac
    NEW="${LINE%\"}:$JAR_REF\""
    head -n $((N - 1)) "$1" > "$2" || return 1
    printf '%s\n' "$NEW" >> "$2" || return 1
    tail -n +$((N + 1)) "$1" >> "$2" || return 1
}

[ -f "$SELF_DIR/stage.conf" ] || fail "stage.conf fehlt" "stage.conf is missing"
. "$SELF_DIR/stage.conf" || fail "stage.conf nicht lesbar" "stage.conf is unreadable"

if [ -z "$SD_BACKUP_DIR" ]; then
    SDN=1
    while [ -e "$SELF_DIR/sd-backup/backup-$SDN" ]; do SDN=$((SDN + 1)); done
    SD_BACKUP_DIR=$SELF_DIR/sd-backup/backup-$SDN
fi

echo "MST2 CarPlay Maps - Installer (Beta)"
echo "Ziel / Target: $TARGET_TRAIN (MU $TARGET_MU), Kennung / id: $TARGET_ID"
echo "Sicherung auf der SD-Karte / SD backup: $SD_BACKUP_DIR"
echo "Vorgesehene Hardware / intended hardware: Radio 3Q0 035 864 (ohne Index/A/B/C), Kombi AID 1 5NA 920 791 (ohne Index/A/B) / radio 3Q0 035 864 (no index/A/B/C), cluster AID 1 5NA 920 791 (no index/A/B)"
echo "Kombi / cluster: nur AID 1 (12,3 Zoll, 1440x540), NICHT AID 2 (10,25 Zoll, 1280x480); der Installer kann das nicht pruefen. / only AID 1 (12.3 inch, 1440x540), NOT AID 2 (10.25 inch, 1280x480); the installer cannot check this."
echo

[ "$(id -u)" = "0" ] || fail "als root starten (Root-Shell)" "run this script from a root shell"
[ -d "$SELF_DIR/payload" ] || fail "Ordner payload fehlt" "payload directory is missing"
[ -d "$SELF_DIR/patched" ] || fail "Ordner patched fehlt" "patched directory is missing"
[ ! -e "$MARKER" ] || fail "bereits installiert; zuerst uninstall.sh ausfuehren" "already installed; run uninstall.sh first"
[ ! -e "$BACKUP_DIR" ] || fail "Sicherungsordner existiert schon; bitte aufbewahren und die frühere Installation pruefen" "backup directory already exists; preserve it and inspect the previous install"

# Zuerst die SD-Karte: nicht beschreibbar = Abbruch, bevor irgendetwas geprueft oder geaendert wird
# SD card first: not writable = abort before anything is checked or changed
sd_writable "$SD_BACKUP_DIR" || fail "SD-Karte nicht beschreibbar (oder Sicherungsziel unbrauchbar): $SD_BACKUP_DIR - Abbruch, am Geraet wurde nichts geaendert" "SD card is not writable (or the backup target is unusable): $SD_BACKUP_DIR - aborting, nothing was changed on the unit"
[ ! -e "$SD_BACKUP_DIR" ] || fail "SD-Sicherungsordner existiert schon: $SD_BACKUP_DIR" "SD backup directory already exists: $SD_BACKUP_DIR"
echo "SD-Karte beschreibbar. / SD card is writable."

expect_pair "$APP_ROOT/cfg/iap2.cfg" "$EXPECT_IAP2" iap2.cfg
expect_pair "$APP_ROOT/hmi/HMI/config/bundles.properties" "$EXPECT_BUNDLES" bundles.properties
expect_pair "$ETC_DIR/procman_core.cfg" "$EXPECT_PROCMAN" procman_core.cfg

# runHMI.sh: Original oder bekannte Community-Variante (z. B. NavIgnore) / stock or known community variant (e.g. NavIgnore)
HMI_LIVE=$APP_ROOT/hmi/HMI/runHMI.sh
[ -f "$HMI_LIVE" ] || fail "Datei fehlt: $HMI_LIVE" "missing file: $HMI_LIVE"
HMI_VARIANT=STOCK
g -q 'NavActiveIgnore.jar' "$HMI_LIVE" && HMI_VARIANT=NAVIGNORE
case " $HMI_VARIANTS " in
    *" $HMI_VARIANT "*) ;;
    *) fail "runHMI.sh ist eine unbekannte Variante ($HMI_VARIANT)" "runHMI.sh is an unknown variant ($HMI_VARIANT)" ;;
esac
eval "HMI_EXPECT=\$EXPECT_HMI_$HMI_VARIANT"
expect_pair "$HMI_LIVE" "$HMI_EXPECT" "runHMI.sh ($HMI_VARIANT)"
echo "runHMI.sh-Variante / variant: $HMI_VARIANT"
g -q "$JAR_REF" "$HMI_LIVE" && fail "runHMI.sh enthaelt das Jar schon" "runHMI.sh already contains the jar"

grep -q 'CarPlay.*-c15' "$ETC_DIR/procman_core.cfg" || fail "CarPlay-Dienst nicht gefunden" "CarPlay service was not found"
grep -q 'NavigationServer.*NavServer.cfg' "$ETC_DIR/procman_core.cfg" || fail "NavigationServer-Dienst nicht gefunden" "NavigationServer service was not found"
grep -q 'LD_PRELOAD=.*/mst2-eu-carplay-maps' "$ETC_DIR/procman_core.cfg" && fail "Prozesskonfiguration ist schon veraendert" "procman configuration is already modified"

# runHMI.sh vorbereiten und pruefen (noch ohne etwas zu aendern) / prepare and verify runHMI.sh (nothing changed yet)
HMI_NEW=${TMPDIR:-/tmp}/mst2-runHMI.new.$$
patch_hmi "$HMI_LIVE" "$HMI_NEW" || { rm -f "${HMI_NEW:?}"; fail "Boot-Klassenpfad in runHMI.sh nicht erkannt" "boot class path in runHMI.sh not recognized"; }
[ "$(g -c "$JAR_REF" "$HMI_NEW")" = "1" ] || { rm -f "${HMI_NEW:?}"; fail "Pruefung der neuen runHMI.sh fehlgeschlagen (Jar-Zahl)" "new runHMI.sh check failed (jar count)"; }
[ "$(wc -l < "$HMI_NEW" | tr -d ' ')" = "$(wc -l < "$HMI_LIVE" | tr -d ' ')" ] || { rm -f "${HMI_NEW:?}"; fail "Pruefung der neuen runHMI.sh fehlgeschlagen (Zeilenzahl)" "new runHMI.sh check failed (line count)"; }
if [ "$HMI_VARIANT" = "STOCK" ]; then
    cmp -s "$HMI_NEW" "$SELF_DIR/patched/hmi/HMI/runHMI.sh" || { rm -f "${HMI_NEW:?}"; fail "neue runHMI.sh weicht von der vorbereiteten Datei ab" "new runHMI.sh differs from the prepared file"; }
fi
if [ "$HMI_VARIANT" = "NAVIGNORE" ]; then
    g -q 'NavActiveIgnore.jar' "$HMI_NEW" || { rm -f "${HMI_NEW:?}"; fail "NavIgnore-Zeile ging verloren" "the NavIgnore line was lost"; }
fi

if [ "$CHECK_ONLY" = "1" ]; then
    rm -f "${HMI_NEW:?}"
    echo
    echo "Pruefung bestanden. Am Geraet wurde NICHTS geaendert."
    echo "  Check passed. NOTHING was changed on the unit."
    exit 0
fi

# QNX akzeptiert mount -uw auf einem bereits eingehaengten Dateisystem. / QNX accepts mount -uw on a mounted filesystem.
mount -uw / >/dev/null 2>&1
mount -uw "$APP_ROOT" >/dev/null 2>&1
touch "$APP_ROOT/.mst2-eu-write-test" 2>/dev/null || { rm -f "${HMI_NEW:?}"; fail "$APP_ROOT ist nicht beschreibbar" "$APP_ROOT is not writable"; }
rm -f "${APP_ROOT:?}/.mst2-eu-write-test"
touch "$ETC_DIR/.mst2-eu-write-test" 2>/dev/null || { rm -f "${HMI_NEW:?}"; fail "$ETC_DIR ist nicht beschreibbar; nichts wurde geaendert" "$ETC_DIR is not writable; no files were changed"; }
rm -f "${ETC_DIR:?}/.mst2-eu-write-test"

# Sicherung 1: auf dem Geraet / backup 1: on the unit
mkdir "$BACKUP_DIR" || fail "Sicherungsordner nicht anlegbar" "could not create backup directory"
cp "$APP_ROOT/cfg/iap2.cfg" "$BACKUP_DIR/iap2.cfg" || discard_incomplete_backup "iap2.cfg nicht sicherbar"
cp "$HMI_LIVE" "$BACKUP_DIR/runHMI.sh" || discard_incomplete_backup "runHMI.sh nicht sicherbar"
cp "$APP_ROOT/hmi/HMI/config/bundles.properties" "$BACKUP_DIR/bundles.properties" || discard_incomplete_backup "bundles.properties nicht sicherbar"
cp "$ETC_DIR/procman_core.cfg" "$BACKUP_DIR/procman_core.cfg" || discard_incomplete_backup "procman_core.cfg nicht sicherbar"
chmod 644 "$BACKUP_DIR/iap2.cfg" "$BACKUP_DIR/bundles.properties" "$BACKUP_DIR/procman_core.cfg" || discard_incomplete_backup "Rechte der Sicherung nicht setzbar"
chmod 755 "$BACKUP_DIR/runHMI.sh" || discard_incomplete_backup "Rechte der Sicherung nicht setzbar"
cmp -s "$APP_ROOT/cfg/iap2.cfg" "$BACKUP_DIR/iap2.cfg" || discard_incomplete_backup "Pruefung der iap2.cfg-Sicherung fehlgeschlagen"
cmp -s "$HMI_LIVE" "$BACKUP_DIR/runHMI.sh" || discard_incomplete_backup "Pruefung der runHMI.sh-Sicherung fehlgeschlagen"
cmp -s "$APP_ROOT/hmi/HMI/config/bundles.properties" "$BACKUP_DIR/bundles.properties" || discard_incomplete_backup "Pruefung der bundles.properties-Sicherung fehlgeschlagen"
cmp -s "$ETC_DIR/procman_core.cfg" "$BACKUP_DIR/procman_core.cfg" || discard_incomplete_backup "Pruefung der procman_core.cfg-Sicherung fehlgeschlagen"
echo "$HMI_VARIANT" > "$BACKUP_DIR/runHMI.variant"

# Sicherung 2: zusaetzlich auf der SD-Karte, jede Datei gegen das Original geprueft
# backup 2: additionally on the SD card, every file verified against the original
mkdir -p "$SD_BACKUP_DIR" || discard_incomplete_backup "SD-Sicherungsordner nicht anlegbar"
SD_CREATED=1
sd_copy() {  # Quelle Zielname
    cp "$1" "$SD_BACKUP_DIR/$2" || return 1
    cmp -s "$1" "$SD_BACKUP_DIR/$2" || return 1
    return 0
}
sd_copy "$APP_ROOT/cfg/iap2.cfg" iap2.cfg || discard_incomplete_backup "iap2.cfg nicht auf die SD-Karte sicherbar"
sd_copy "$HMI_LIVE" runHMI.sh || discard_incomplete_backup "runHMI.sh nicht auf die SD-Karte sicherbar"
sd_copy "$APP_ROOT/hmi/HMI/config/bundles.properties" bundles.properties || discard_incomplete_backup "bundles.properties nicht auf die SD-Karte sicherbar"
sd_copy "$ETC_DIR/procman_core.cfg" procman_core.cfg || discard_incomplete_backup "procman_core.cfg nicht auf die SD-Karte sicherbar"
echo "$HMI_VARIANT" > "$SD_BACKUP_DIR/runHMI.variant" || discard_incomplete_backup "SD-Sicherung nicht vollstaendig"
{
    echo "Ziel / target: $TARGET_TRAIN ($TARGET_ID)"
    echo "Datum / date: $(date 2>/dev/null)"
    echo "Pfade auf dem Geraet / paths on the unit: $APP_ROOT/cfg/iap2.cfg, $HMI_LIVE, $APP_ROOT/hmi/HMI/config/bundles.properties, $ETC_DIR/procman_core.cfg"
    for f in $BACKUP_FILES; do
        if command -v sha256sum >/dev/null 2>&1; then
            echo "$(bytes "$SD_BACKUP_DIR/$f") $(sha256sum "$SD_BACKUP_DIR/$f" | awk '{print $1}') $f"
        else
            echo "$(bytes "$SD_BACKUP_DIR/$f") - $f"
        fi
    done
} > "$SD_BACKUP_DIR/MANIFEST.txt" || discard_incomplete_backup "SD-Sicherung nicht vollstaendig"
{
    echo "Sicherung der Originaldateien vor der Installation von MST2 CarPlay Maps. Zur Analyse aufbewahren."
    echo "  Backup of the original files before installing MST2 CarPlay Maps. Keep for analysis."
} > "$SD_BACKUP_DIR/LIESMICH.txt" || discard_incomplete_backup "SD-Sicherung nicht vollstaendig"
for f in $BACKUP_FILES; do
    cmp -s "$SD_BACKUP_DIR/$f" "$BACKUP_DIR/$f" || discard_incomplete_backup "SD-Sicherung weicht von der Geraete-Sicherung ab ($f)"
done
echo "Sicherungen angelegt und geprueft: $BACKUP_DIR und $SD_BACKUP_DIR"
echo "  Backups created and verified: $BACKUP_DIR and $SD_BACKUP_DIR"

mkdir "$INSTALL_DIR" || rollback
copy_checked "$SELF_DIR/payload/libmst2_eu_ipod.so" "$INSTALL_DIR/libmst2_eu_ipod.so" 755 || rollback
copy_checked "$SELF_DIR/payload/libmst2_eu_launch.so" "$INSTALL_DIR/libmst2_eu_launch.so" 755 || rollback
copy_checked "$SELF_DIR/payload/libmst2_eu_video_gate.so" "$INSTALL_DIR/libmst2_eu_video_gate.so" 755 || rollback
copy_checked "$SELF_DIR/payload/libmst2_eu_airplay.so" "$INSTALL_DIR/libmst2_eu_airplay.so" 755 || rollback
copy_checked "$SELF_DIR/payload/mst2-eu-rgi-hmi.jar" "$JAR_FILE" 644 || rollback
copy_checked "$SELF_DIR/patched/cfg/iap2.cfg" "$APP_ROOT/cfg/iap2.cfg" 644 || rollback
copy_checked "$HMI_NEW" "$HMI_LIVE" 755 || rollback
copy_checked "$SELF_DIR/patched/hmi/HMI/config/bundles.properties" "$APP_ROOT/hmi/HMI/config/bundles.properties" 644 || rollback
copy_checked "$SELF_DIR/patched/etc/procman_core.cfg" "$ETC_DIR/procman_core.cfg" 644 || rollback
rm -f "${HMI_NEW:?}"

echo "$TARGET_TRAIN beta" > "$MARKER" || rollback
sync
command -v MountPathSync >/dev/null 2>&1 && MountPathSync "$APP_ROOT"

echo
echo "Wenn etwas schiefgeht: Logs und Sicherungen aufheben und melden! / If anything goes wrong: keep and report the logs and backups!"
echo "Installation erfolgreich abgeschlossen."
echo "  Installation completed successfully."
echo "Sicherung auf dem Geraet / backup on the unit: $BACKUP_DIR"
echo "Sicherung auf der SD-Karte / backup on the SD card: $SD_BACKUP_DIR"
echo "SD-Karte entfernen, dann das Geraet von Hand neu starten. / Remove the SD card, then reboot the unit manually."
echo "Telnet- oder serielle Verbindung fuer den ersten Start offen halten. / Keep serial/Telnet access available for the first boot."
