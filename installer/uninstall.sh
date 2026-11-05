#!/bin/ksh

# Stellt die Originaldateien wieder her und entfernt danach ALLES von diesem Projekt vom Geraet (Nutzlast UND die Sicherung auf
# dem Geraet) - oder benennt es nur um (UNINSTALL_MODE=rename, nichts geht verloren). Die Sicherung auf der SD-Karte bleibt erhalten.
# Quelle fuer jede Originaldatei, in dieser Reihenfolge: 1. die Sicherung von install.sh (auf dem Geraet oder BACKUP_DIR_OVERRIDE),
# 2. fuer runHMI.sh der Rueckbau unseres Jars aus der aktuellen Datei (bewahrt auch eine Community-Variante), 3. eine eigene Kopie der
# Originale im Ordner stock/ neben diesem Skript (nur im SD-Paket, nie im oeffentlichen Repo). Jede Quelle wird vorher geprueft
# (Groesse laut stage.conf); fehlt fuer eine Datei eine gueltige Quelle, wird VOR jeder Aenderung abgebrochen.
# Restores the stock files and then removes EVERYTHING of this project from the unit (payload AND the backup on the unit) - or only
# renames it (UNINSTALL_MODE=rename, nothing is lost). The backup on the SD card is kept.
# Source of every stock file, in this order: 1. the backup made by install.sh (on the unit or BACKUP_DIR_OVERRIDE), 2. for runHMI.sh
# removing our jar from the current file (also keeps a community variant), 3. an own copy of the stock files in stock/ next to this
# script (SD package only, never in the public repository). Every source is checked first (size from stage.conf); if a file has no
# valid source the script aborts BEFORE any change.
# Jede Meldung steht zuerst auf Deutsch, darunter auf Englisch. / Every message is German first, English below.

set -u

# Eigener Ordner ohne dirname (fehlt auf dem Radio) / own folder without dirname (missing on the radio)
case $0 in
    */*)
        _sd=${0%/*}
        [ -n "$_sd" ] || _sd=/
        ;;
    *) _sd=. ;;
esac
SELF_DIR=$(cd "$_sd" && pwd)
# APP_ROOT, ETC_DIR, SD_BACKUP_DIR und BACKUP_DIR_OVERRIDE lassen sich fuer Tests/Notfaelle umbiegen
# can be redirected for tests/emergencies. BACKUP_DIR_OVERRIDE: Kopie der Sicherung, z. B. von der SD-Karte / copy of the backup, e.g. from the SD card
APP_ROOT=${APP_ROOT:-/extbin/apps}
ETC_DIR=${ETC_DIR:-/etc}
INSTALL_DIR=$APP_ROOT/mst2-eu-carplay-maps
MMI_BACKUP_DIR=$APP_ROOT/mst2-eu-carplay-maps-backup
BACKUP_DIR=${BACKUP_DIR_OVERRIDE:-$MMI_BACKUP_DIR}
SD_BACKUP_DIR=${SD_BACKUP_DIR:-}
BACKUP_FILES="iap2.cfg runHMI.sh bundles.properties procman_core.cfg"
STOCK_DIR=${STOCK_DIR:-$SELF_DIR/stock}
UNINSTALL_MODE=${UNINSTALL_MODE:-delete}        # delete | rename
UNINSTALL_SUFFIX=${UNINSTALL_SUFFIX:-$$}
JAR_REF=/extbin/apps/mst2-eu-carplay-maps/mst2-eu-rgi-hmi.jar
HMI_LIVE=$APP_ROOT/hmi/HMI/runHMI.sh

fail() {
    echo "FEHLER: $1"
    echo "  ERROR: $2"
    exit 1
}

restore() {  # restore QUELLE ZIEL RECHTE
    cp "$1" "$2" || fail "$2 nicht wiederherstellbar" "could not restore $2"
    chmod "$3" "$2" || fail "Rechte von $2 nicht setzbar" "could not restore permissions for $2"
    t_same "$1" "$2" || fail "Pruefung von $2 fehlgeschlagen" "verification failed for $2"
}

[ -f "$SELF_DIR/tools.sh" ] || fail "tools.sh fehlt in $SELF_DIR" "tools.sh is missing in $SELF_DIR"
. "$SELF_DIR/tools.sh" || fail "tools.sh nicht lesbar" "tools.sh is unreadable"

echo "MST2 CarPlay Maps - Deinstallation (Beta)"
echo "  uninstaller"
t_report
t_isroot || fail "als root starten (Root-Shell)" "run this script from a root shell"
MISSING=$(t_missing_essential)
[ -z "$MISSING" ] || fail "auf diesem Radio fehlen zwingend benoetigte Programme:$MISSING - es wurde nichts geaendert" "essential programs are missing on this radio:$MISSING - nothing was changed"
[ -f "$SELF_DIR/stage.conf" ] && . "$SELF_DIR/stage.conf"

# Erwartete Groesse bzw. SHA-256 einer Originaldatei laut stage.conf (leer = unbekannt) / expected size or SHA-256 per stage.conf
expect_of() {
    case $1 in
        iap2.cfg) echo "${EXPECT_IAP2:-}" ;;
        bundles.properties) echo "${EXPECT_BUNDLES:-}" ;;
        procman_core.cfg) echo "${EXPECT_PROCMAN:-}" ;;
        runHMI.sh) echo "${EXPECT_HMI_STOCK:-}" ;;
    esac
}
# Ist DATEI eine gueltige Kopie des Originals NAME? Groesse immer (wenn bekannt), SHA-256 wenn das Radio sha256sum hat
# Is FILE a valid copy of the original NAME? Size always (if known), SHA-256 when the radio has sha256sum
ok_copy() {
    [ -f "$1" ] || return 1
    _e=$(expect_of "$2")
    [ -n "$_e" ] || return 0
    [ "$(t_size "$1")" = "${_e%% *}" ] || return 1
    if [ "$H_sha256sum" = "1" ]; then
        _h=$(t_sha "$1")
        if [ "$2" = "runHMI.sh" ]; then
            [ "$_h" = "${_e##* }" ] || [ "$_h" = "${EXPECT_HMI_NAVIGNORE##* }" ] || return 1
        else
            [ "$_h" = "${_e##* }" ] || return 1
        fi
    fi
    return 0
}

# Rueckbau: unser Jar aus der BOOTCLASSPATH-Zeile der aktuellen runHMI.sh entfernen (Umkehrung von install.sh; byte-genau)
# Reversal: remove our jar from the BOOTCLASSPATH line of the current runHMI.sh (inverse of install.sh; byte-exact)
reverse_hmi() {
    REV_HMI=${TMPDIR:-/tmp}/mst2-runHMI.rev.$$
    [ -f "$HMI_LIVE" ] || return 1
    LC_ALL=C grep -q "$JAR_REF" "$HMI_LIVE" || return 1
    RV_SUFFIX=":$JAR_REF\""
    t_selftest_nonl
    : > "$REV_HMI" || return 1
    RV_DONE=0
    while :; do
        if IFS= read -r RV_LINE; then
            RV_NL=1
        else
            RV_NL=0
            [ -n "$RV_LINE" ] || break
        fi
        if [ "$RV_DONE" = "0" ]; then
            case $RV_LINE in
                BOOTCLASSPATH=\"/*)
                    case $RV_LINE in
                        *"$RV_SUFFIX")
                            RV_LINE=${RV_LINE%"$RV_SUFFIX"}
                            RV_LINE="$RV_LINE\""
                            RV_DONE=1
                            ;;
                    esac
                    ;;
            esac
        fi
        if [ "$RV_NL" = "1" ]; then t_emit "$RV_LINE" >> "$REV_HMI" || return 1; else t_emit_nonl "$RV_LINE" >> "$REV_HMI" || return 1; fi
    done < "$HMI_LIVE"
    [ "$RV_DONE" = "1" ] || { rm -f "${REV_HMI:?}"; return 1; }
    [ "$(t_size "$REV_HMI")" = "$(( $(t_size "$HMI_LIVE") - ${#JAR_REF} - 1 ))" ] || { rm -f "${REV_HMI:?}"; return 1; }
    LC_ALL=C grep -q "$JAR_REF" "$REV_HMI" && { rm -f "${REV_HMI:?}"; return 1; }
    ok_copy "$REV_HMI" runHMI.sh || { rm -f "${REV_HMI:?}"; return 1; }
    return 0
}

# Quelle fuer NAME waehlen: setzt PICK (Pfad) und PICK_HOW / choose the source for NAME: sets PICK (path) and PICK_HOW
pick() {
    PICK=""
    PICK_HOW=""
    if ok_copy "$BACKUP_DIR/$1" "$1"; then
        PICK=$BACKUP_DIR/$1
        PICK_HOW="Sicherung von install.sh / backup from install.sh ($BACKUP_DIR)"
        return 0
    fi
    if [ "$1" = "runHMI.sh" ] && reverse_hmi; then
        PICK=$REV_HMI
        PICK_HOW="Rueckbau unseres Jars / removal of our jar"
        return 0
    fi
    if ok_copy "$STOCK_DIR/$1" "$1"; then
        PICK=$STOCK_DIR/$1
        PICK_HOW="eigene Kopie der Originale / built-in copy of the stock files ($STOCK_DIR)"
        return 0
    fi
    return 1
}

if [ "$UNINSTALL_MODE" = "rename" ] && [ "$H_mv" != "1" ]; then
    echo "Hinweis: Dieses Radio hat kein mv; es kann nicht umbenannt werden, es wird stattdessen geloescht (Modus delete)."
    echo "  Note: this radio has no mv; renaming is not possible, deleting instead (mode delete)."
    UNINSTALL_MODE=delete
fi
echo "Modus / mode: $UNINSTALL_MODE (rename = umbenennen statt loeschen / rename instead of delete)"
# ALLE Quellen waehlen und pruefen, bevor irgendetwas geaendert wird / choose and check ALL sources before anything is changed
pick iap2.cfg || fail "keine gueltige Quelle fuer iap2.cfg (weder Sicherung noch eigene Kopie) - nichts wurde geaendert" "no valid source for iap2.cfg (neither backup nor own copy) - nothing was changed"
S_IAP2=$PICK; echo "iap2.cfg <- $PICK_HOW"
pick runHMI.sh || fail "keine gueltige Quelle fuer runHMI.sh (weder Sicherung noch Rueckbau) - nichts wurde geaendert" "no valid source for runHMI.sh (neither backup nor jar removal) - nothing was changed"
S_HMI=$PICK; echo "runHMI.sh <- $PICK_HOW"
pick bundles.properties || fail "keine gueltige Quelle fuer bundles.properties - nichts wurde geaendert" "no valid source for bundles.properties - nothing was changed"
S_BUNDLES=$PICK; echo "bundles.properties <- $PICK_HOW"
pick procman_core.cfg || fail "keine gueltige Quelle fuer procman_core.cfg - nichts wurde geaendert" "no valid source for procman_core.cfg - nothing was changed"
S_PROCMAN=$PICK; echo "procman_core.cfg <- $PICK_HOW"

mount -uw / >/dev/null 2>&1
mount -uw "$APP_ROOT" >/dev/null 2>&1
t_writetest "$APP_ROOT" || fail "$APP_ROOT ist nicht beschreibbar" "$APP_ROOT is not writable"
t_writetest "$ETC_DIR" || fail "$ETC_DIR ist nicht beschreibbar" "$ETC_DIR is not writable"

# 1. Originale zurueck und einzeln pruefen / put the originals back and verify each one
restore "$S_IAP2" "$APP_ROOT/cfg/iap2.cfg" 644
restore "$S_HMI" "$HMI_LIVE" 755
restore "$S_BUNDLES" "$APP_ROOT/hmi/HMI/config/bundles.properties" 644
restore "$S_PROCMAN" "$ETC_DIR/procman_core.cfg" 644
[ -z "${REV_HMI:-}" ] || rm -f "${REV_HMI:?}"
echo "Originaldateien wiederhergestellt und geprueft."
echo "  Stock files restored and verified."

# 2. Kopie der Geraete-Sicherung auf die SD-Karte (zur Analyse), nur wenn die Sicherung vom Geraet stammt
# 2. copy of the on-unit backup to the SD card (for analysis), only if the backup comes from the unit
if [ "$BACKUP_DIR" = "$MMI_BACKUP_DIR" ] && [ -d "$MMI_BACKUP_DIR" ]; then
    if [ -z "$SD_BACKUP_DIR" ]; then
        SDN=1
        while [ -e "$SELF_DIR/sd-backup/vor-deinstallation-$SDN" ]; do SDN=$((SDN + 1)); done
        SD_BACKUP_DIR=$SELF_DIR/sd-backup/vor-deinstallation-$SDN
    fi
    SD_OK=1
    mkdir -p "$SD_BACKUP_DIR" 2>/dev/null || SD_OK=0
    if [ "$SD_OK" = "1" ]; then
        for f in $BACKUP_FILES runHMI.variant; do
            [ -f "$BACKUP_DIR/$f" ] || continue
            cp "$BACKUP_DIR/$f" "$SD_BACKUP_DIR/$f" 2>/dev/null && t_same "$BACKUP_DIR/$f" "$SD_BACKUP_DIR/$f" || SD_OK=0
        done
    fi
    if [ "$SD_OK" = "1" ]; then
        echo "Kopie der Sicherung auf der SD-Karte: $SD_BACKUP_DIR"
        echo "  Copy of the backup on the SD card: $SD_BACKUP_DIR"
    else
        echo "WARNUNG: Die Sicherung konnte nicht auf die SD-Karte kopiert werden. Sie wird trotzdem vom Geraet entfernt, weil die Originale zurueck sind."
        echo "  WARNING: the backup could not be copied to the SD card. It is removed from the unit anyway because the originals are back."
    fi
elif [ "$BACKUP_DIR" != "$MMI_BACKUP_DIR" ]; then
    echo "Sicherung stammt aus einer Kopie (BACKUP_DIR_OVERRIDE); sie wird nicht veraendert."
    echo "  The backup comes from a copy (BACKUP_DIR_OVERRIDE); it is left untouched."
else
    echo "Auf dem Geraet gibt es keine Sicherung; die Originale kamen aus dem Rueckbau bzw. aus der eigenen Kopie."
    echo "  There is no backup on the unit; the originals came from the removal / the own copy."
fi

# 3. ALLES von diesem Projekt vom Geraet entfernen (delete) oder umbenennen (rename) / remove (delete) or rename (rename) EVERYTHING of this project
rename_away() {  # Ordner umbenennen, nichts loeschen / rename a folder, delete nothing
    [ -e "$1" ] || return 0
    _n=$1.entfernt-$UNINSTALL_SUFFIX
    _i=1
    while [ -e "$_n" ]; do _n=$1.entfernt-$UNINSTALL_SUFFIX-$_i; _i=$((_i + 1)); done
    t_mv "$1" "$_n" || fail "$1 nicht umbenennbar" "could not rename $1"
    echo "Umbenannt (nicht geloescht) / renamed (not deleted): $1 -> $_n"
}
if [ "$UNINSTALL_MODE" = "rename" ]; then
    rename_away "$INSTALL_DIR"
    rename_away "$MMI_BACKUP_DIR"
else
    rm -f "${INSTALL_DIR:?}/libmst2_eu_ipod.so" "${INSTALL_DIR:?}/libmst2_eu_launch.so"
    rm -f "${INSTALL_DIR:?}/libmst2_eu_video_gate.so" "${INSTALL_DIR:?}/libmst2_eu_airplay.so"
    rm -f "${INSTALL_DIR:?}/mst2-eu-rgi-hmi.jar" "${INSTALL_DIR:?}/.installed"
    t_rmdir "$INSTALL_DIR"
    for f in $BACKUP_FILES runHMI.variant; do
        rm -f "${MMI_BACKUP_DIR:?}/${f:?}"
    done
    t_rmdir "$MMI_BACKUP_DIR"
fi
t_sync
t_have MountPathSync && MountPathSync "$APP_ROOT"

# 4. Kontrolle: nichts darf zurueckbleiben / check: nothing may remain
LEFT=0
if [ -e "$INSTALL_DIR" ]; then
    LEFT=1
    echo "FEHLER: Es sind Reste auf dem Geraet geblieben: $INSTALL_DIR"
    echo "  ERROR: leftovers remain on the unit: $INSTALL_DIR"
    t_lsall "$INSTALL_DIR"
fi
if [ -e "$MMI_BACKUP_DIR" ]; then
    LEFT=1
    echo "FEHLER: Es sind Reste auf dem Geraet geblieben: $MMI_BACKUP_DIR"
    echo "  ERROR: leftovers remain on the unit: $MMI_BACKUP_DIR"
    t_lsall "$MMI_BACKUP_DIR"
fi
[ "$LEFT" = "0" ] || exit 1

# 5. Nachkontrolle: nichts darf von diesem Projekt vergessen worden sein / final check: nothing of this project may be forgotten
echo "Nachkontrolle / final check:"
BAD=0
for pair in "iap2.cfg:$APP_ROOT/cfg/iap2.cfg" "runHMI.sh:$HMI_LIVE" "bundles.properties:$APP_ROOT/hmi/HMI/config/bundles.properties" "procman_core.cfg:$ETC_DIR/procman_core.cfg"; do
    _n=${pair%%:*}
    _f=${pair#*:}
    if LC_ALL=C grep -q "mst2-eu" "$_f"; then
        BAD=1
        echo "  FEHLER: $_f enthaelt noch einen Verweis auf dieses Projekt (mst2-eu)"
        echo "  ERROR: $_f still refers to this project (mst2-eu)"
    elif ok_copy "$_f" "$_n"; then
        echo "  OK  $_n: Original (Groesse/Pruefsumme stimmt, kein Verweis auf dieses Projekt)"
    else
        BAD=1
        echo "  FEHLER: $_n hat nicht die Groesse bzw. Pruefsumme des Originals"
        echo "  ERROR: $_n does not have the size or checksum of the original"
    fi
done
if [ "$UNINSTALL_MODE" != "rename" ]; then
    LEFTOVER=$(ls "$APP_ROOT" 2>/dev/null | grep "^mst2-eu")
    if [ -n "$LEFTOVER" ]; then
        BAD=1
        echo "  FEHLER: in $APP_ROOT ist noch etwas von diesem Projekt: $LEFTOVER"
        echo "  ERROR: something of this project is still in $APP_ROOT: $LEFTOVER"
    else
        echo "  OK  in $APP_ROOT ist nichts von diesem Projekt (mst2-eu*) mehr"
    fi
fi
[ "$BAD" = "0" ] || exit 1

echo
if [ "$UNINSTALL_MODE" = "rename" ]; then
    echo "Deinstallation abgeschlossen: Unser Ordner und die Sicherung auf dem Geraet wurden UMBENANNT (Endung .entfernt-$UNINSTALL_SUFFIX), nicht geloescht."
    echo "  Uninstall complete: our folder and the backup on the unit were RENAMED (suffix .entfernt-$UNINSTALL_SUFFIX), not deleted."
else
    echo "Deinstallation abgeschlossen: Auf dem Geraet ist nichts von diesem Projekt zurueckgeblieben."
    echo "  Uninstall complete: nothing of this project remains on the unit."
fi
[ -n "$SD_BACKUP_DIR" ] && [ -d "$SD_BACKUP_DIR" ] && echo "Die Sicherung auf der SD-Karte bleibt erhalten: $SD_BACKUP_DIR" && echo "  The backup on the SD card is kept: $SD_BACKUP_DIR"
echo "SD-Karte entfernen, dann das Geraet von Hand neu starten. / Remove the SD card, then reboot the unit manually."
exit 0
