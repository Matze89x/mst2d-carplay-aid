#!/bin/ksh

# Stellt die von install.sh gesicherten Originaldateien wieder her und entfernt danach ALLES von diesem Projekt vom Geraet
# (Nutzlast UND die Sicherung auf dem Geraet). Die Sicherung auf der SD-Karte bleibt zur Analyse erhalten.
# Restores the stock files saved by install.sh and then removes EVERYTHING of this project from the unit (payload AND the
# backup on the unit). The backup on the SD card is kept for analysis.
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

fail() {
    echo "FEHLER: $1"
    echo "  ERROR: $2"
    exit 1
}

restore() {
    cp "$BACKUP_DIR/$1" "$2" || fail "$2 nicht wiederherstellbar" "could not restore $2"
    chmod "$3" "$2" || fail "Rechte von $2 nicht setzbar" "could not restore permissions for $2"
    t_same "$BACKUP_DIR/$1" "$2" || fail "Pruefung von $2 fehlgeschlagen" "verification failed for $2"
}

[ -f "$SELF_DIR/tools.sh" ] || fail "tools.sh fehlt in $SELF_DIR" "tools.sh is missing in $SELF_DIR"
. "$SELF_DIR/tools.sh" || fail "tools.sh nicht lesbar" "tools.sh is unreadable"

echo "MST2 CarPlay Maps - Deinstallation (Beta)"
echo "  uninstaller"
t_report
t_isroot || fail "als root starten (Root-Shell)" "run this script from a root shell"
MISSING=$(t_missing_essential)
[ -z "$MISSING" ] || fail "auf diesem Radio fehlen zwingend benoetigte Programme:$MISSING - es wurde nichts geaendert" "essential programs are missing on this radio:$MISSING - nothing was changed"
for f in $BACKUP_FILES; do
    [ -f "$BACKUP_DIR/$f" ] || fail "Sicherung unvollstaendig oder nicht gefunden: $BACKUP_DIR/$f" "stock backup is incomplete or not found: $BACKUP_DIR/$f"
done

mount -uw / >/dev/null 2>&1
mount -uw "$APP_ROOT" >/dev/null 2>&1
t_writetest "$APP_ROOT" || fail "$APP_ROOT ist nicht beschreibbar" "$APP_ROOT is not writable"
t_writetest "$ETC_DIR" || fail "$ETC_DIR ist nicht beschreibbar" "$ETC_DIR is not writable"

# 1. Originale zurueck und einzeln pruefen / put the originals back and verify each one
restore iap2.cfg "$APP_ROOT/cfg/iap2.cfg" 644
restore runHMI.sh "$APP_ROOT/hmi/HMI/runHMI.sh" 755
restore bundles.properties "$APP_ROOT/hmi/HMI/config/bundles.properties" 644
restore procman_core.cfg "$ETC_DIR/procman_core.cfg" 644
echo "Originaldateien wiederhergestellt und geprueft."
echo "  Stock files restored and verified."

# 2. Kopie der Geraete-Sicherung auf die SD-Karte (zur Analyse), nur wenn die Sicherung vom Geraet stammt
# 2. copy of the on-unit backup to the SD card (for analysis), only if the backup comes from the unit
if [ "$BACKUP_DIR" = "$MMI_BACKUP_DIR" ]; then
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
else
    echo "Sicherung stammt aus einer Kopie (BACKUP_DIR_OVERRIDE); sie wird nicht veraendert."
    echo "  The backup comes from a copy (BACKUP_DIR_OVERRIDE); it is left untouched."
fi

# 3. ALLES von diesem Projekt vom Geraet entfernen / remove EVERYTHING of this project from the unit
rm -f "${INSTALL_DIR:?}/libmst2_eu_ipod.so" "${INSTALL_DIR:?}/libmst2_eu_launch.so"
rm -f "${INSTALL_DIR:?}/libmst2_eu_video_gate.so" "${INSTALL_DIR:?}/libmst2_eu_airplay.so"
rm -f "${INSTALL_DIR:?}/mst2-eu-rgi-hmi.jar" "${INSTALL_DIR:?}/.installed"
t_rmdir "$INSTALL_DIR"
for f in $BACKUP_FILES runHMI.variant; do
    rm -f "${MMI_BACKUP_DIR:?}/${f:?}"
done
t_rmdir "$MMI_BACKUP_DIR"
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

echo
echo "Deinstallation abgeschlossen: Auf dem Geraet ist nichts von diesem Projekt zurueckgeblieben."
echo "  Uninstall complete: nothing of this project remains on the unit."
[ -n "$SD_BACKUP_DIR" ] && [ -d "$SD_BACKUP_DIR" ] && echo "Die Sicherung auf der SD-Karte bleibt erhalten: $SD_BACKUP_DIR" && echo "  The backup on the SD card is kept: $SD_BACKUP_DIR"
echo "SD-Karte entfernen, dann das Geraet von Hand neu starten. / Remove the SD card, then reboot the unit manually."
exit 0
