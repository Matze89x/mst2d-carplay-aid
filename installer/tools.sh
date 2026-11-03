# tools.sh - Werkzeug-Schicht fuer install.sh, uninstall.sh und das SD-Skript delphi.sh. ASCII-only, LF-Zeilenenden.
# Tool layer for install.sh, uninstall.sh and the SD script delphi.sh. ASCII only, LF line endings.
#
# Wird mit "." eingelesen, nicht direkt ausgefuehrt. / Sourced with ".", not executed directly.
#
# Warum es das gibt / why this exists: Das Delphi-MST2 fuehrt delphi.sh beim Start mit einer sehr kleinen Werkzeugausstattung
# aus. Der erste Test in einem echten Radio zeigte: dirname, cksum, id, tail, uptime und expr fehlen. Darum nutzen alle
# Skripte nur noch wenige sichere Programme direkt (siehe T_ESSENTIAL) und gehen fuer alles andere ueber die Funktionen
# t_*: Ist das Programm da, wird es benutzt, sonst springt eine reine Shell-Loesung ein. Fehlt etwas Zwingendes, bricht
# t_check_essential VOR jeder Aenderung mit einer klaren Meldung ab.
# The Delphi MST2 runs delphi.sh at boot with a very small toolset. The first test in a real radio showed that dirname,
# cksum, id, tail, uptime and expr are missing. All scripts therefore call only a few safe programs directly (see
# T_ESSENTIAL) and use the t_* functions for everything else: if the program exists it is used, otherwise a pure shell
# fallback takes over. If something essential is missing, t_check_essential aborts BEFORE any change with a clear message.
#
# Nur fuer Proben / rehearsal only: MST2_FORCE_MISSING="cmp wc ..." tut so, als fehlten diese Programme;
# MST2_NO_EXTRA_PATH=1 haengt keine Radio-Ordner an PATH.

T_LOADED=1
T_ESSENTIAL="cp rm mkdir chmod ls mount grep"
T_OPTIONAL="rmdir cmp diff wc head tail cut tr awk id dirname touch sha256sum cksum date uptime sync mv expr sleep cat"

# PATH wie das Boot-Skript des Radios (/etc/rc) plus die ueblichen Ordner / PATH like the radio's boot script plus the usual folders
if [ "${MST2_NO_EXTRA_PATH:-0}" != "1" ]; then
    [ -n "${PATH:-}" ] || PATH=/proc/boot
    for _d in /proc/boot /extbin/apps/bin /ifs2 /ifs1 /extbin/apps/usr/bin /ffs/sbin /bin /usr/bin /sbin /usr/sbin /usr/local/bin; do
        case ":$PATH:" in
            *":$_d:"*) ;;
            *) PATH="$PATH:$_d" ;;
        esac
    done
    export PATH
fi

# Gibt es das Programm im Suchpfad? Nur Shell-Mittel, kein "command -v"/"which". / Is the program on PATH? Shell builtins only.
t_have() {
    case " ${MST2_FORCE_MISSING:-} " in
        *" $1 "*) return 1 ;;
    esac
    _o=$IFS
    IFS=:
    for _p in $PATH; do
        [ -n "$_p" ] || _p=.
        if [ -x "$_p/$1" ] && [ ! -d "$_p/$1" ]; then
            IFS=$_o
            return 0
        fi
    done
    IFS=$_o
    return 1
}

# Einmal pruefen, Ergebnis in H_<name> (1 = vorhanden) / check once, result in H_<name> (1 = present)
for _t in $T_ESSENTIAL $T_OPTIONAL; do
    if t_have "$_t"; then eval "H_$_t=1"; else eval "H_$_t=0"; fi
done

# Welche Zeile-fuer-Zeile-Ausgabe ist byte-genau (auch Rueckstriche bleiben unveraendert)? / which line output is byte-exact (backslashes stay unchanged too)?
_bs='a\nb\tc'
if [ "${MST2_FORCE_EMIT:-}" != "" ]; then
    T_EMIT=$MST2_FORCE_EMIT
elif [ "`printf '%s' "$_bs" 2>/dev/null`" = "$_bs" ]; then
    T_EMIT=printf
elif [ "`print -r -- "$_bs" 2>/dev/null`" = "$_bs" ]; then
    T_EMIT=print
else
    T_EMIT=echo
fi
t_emit() {  # eine Zeile unveraendert ausgeben (keine Escape-Folgen) / print one line unchanged (no escape sequences)
    case $T_EMIT in
        printf) printf '%s\n' "$1" ;;
        print) print -r -- "$1" ;;
        *) echo "$1" ;;
    esac
}
T_NONL=$T_EMIT
t_emit_nonl() {  # wie t_emit, aber ohne Zeilenende / like t_emit but without a line ending
    case $T_NONL in
        printf) printf '%s' "$1" ;;
        print) print -rn -- "$1" ;;
        awk) LINE=$1 awk 'BEGIN { printf "%s", ENVIRON["LINE"] }' ;;
        *) echo "$1" ;;
    esac
}

t_dirname() {
    _x=$1
    while [ "$_x" != "/" ] && [ "${_x%/}" != "$_x" ]; do _x=${_x%/}; done
    case $_x in
        */*)
            _r=${_x%/*}
            [ -n "$_r" ] || _r=/
            ;;
        *) _r=. ;;
    esac
    echo "$_r"
}

t_size() {  # Dateigroesse in Byte / file size in bytes
    _f=$1
    if [ "$H_wc" = "1" ]; then
        _s=$(wc -c < "$_f" 2>/dev/null)
        set -- $_s
        echo "${1:-}"
    else
        _s=$(ls -l "$_f" 2>/dev/null)
        set -- $_s
        echo "${5:-}"
    fi
}

t_lines() {  # Zeilenzahl / line count
    _f=$1
    if [ "$H_wc" = "1" ]; then
        _s=$(wc -l < "$_f" 2>/dev/null)
        set -- $_s
        echo "${1:-}"
    else
        _n=0
        while IFS= read -r _l || [ -n "$_l" ]; do _n=$((_n + 1)); _l=; done < "$_f"
        echo "$_n"
    fi
}

t_sha() {  # SHA-256 oder leer, wenn das Radio kein sha256sum hat / SHA-256 or empty when the radio has no sha256sum
    if [ "$H_sha256sum" = "1" ]; then
        _s=$(sha256sum "$1" 2>/dev/null)
        set -- $_s
        echo "${1:-}"
    else
        echo ""
    fi
}

# Sind zwei Dateien gleich? Vergleichsverfahren (so stark wie das Radio es kann): cmp, diff, SHA-256, cksum, Groesse.
# Are two files identical? Method (as strong as the radio allows): cmp, diff, SHA-256, cksum, size.
t_same_method() {
    if [ "$H_cmp" = "1" ]; then echo cmp
    elif [ "$H_diff" = "1" ]; then echo diff
    elif [ "$H_sha256sum" = "1" ]; then echo sha256
    elif [ "$H_cksum" = "1" ]; then echo cksum
    else echo groesse-size; fi
}
t_same() {
    _a=$1
    _b=$2
    if [ "$H_cmp" = "1" ]; then
        cmp -s "$_a" "$_b"
        return $?
    fi
    if [ "$H_diff" = "1" ]; then
        diff "$_a" "$_b" >/dev/null 2>&1
        return $?
    fi
    if [ "$H_sha256sum" = "1" ]; then
        _ha=$(t_sha "$_a")
        _hb=$(t_sha "$_b")
        [ -n "$_ha" ] && [ "$_ha" = "$_hb" ]
        return $?
    fi
    if [ "$H_cksum" = "1" ]; then
        _ha=$(cksum < "$_a" 2>/dev/null)
        _hb=$(cksum < "$_b" 2>/dev/null)
        [ -n "$_ha" ] && [ "$_ha" = "$_hb" ]
        return $?
    fi
    _sa=$(t_size "$_a")
    _sb=$(t_size "$_b")
    [ -n "$_sa" ] && [ "$_sa" = "$_sb" ]
}

t_isroot() {  # root? Wenn das Radio kein id hat: unbekannt = ja, die Schreibpruefungen entscheiden spaeter / unknown = yes
    if [ "$H_id" = "1" ]; then
        [ "$(id -u 2>/dev/null)" = "0" ]
        return $?
    fi
    if [ -n "${UID:-}" ]; then
        [ "$UID" = "0" ]
        return $?
    fi
    return 0
}

t_writetest() {  # Ordner beschreibbar? Probedatei anlegen und wieder loeschen (ohne touch) / folder writable? create and remove a probe file
    _w=$1/.mst2-write-test
    ( : > "$_w" ) 2>/dev/null || return 1
    [ -f "$_w" ] || return 1
    rm -f "${_w:?}"
    return 0
}

t_sync() {
    [ "$H_sync" = "1" ] && sync
    return 0
}

t_date() {
    if [ "$H_date" = "1" ]; then date 2>/dev/null; else echo "(kein date / no date)"; fi
}

t_mv() {  # verschieben; ohne mv: kopieren und loeschen / move; without mv: copy and delete
    if [ "$H_mv" = "1" ]; then
        mv -f "$1" "$2" 2>/dev/null
        return $?
    fi
    cp "$1" "$2" 2>/dev/null && rm -f "${1:?}"
}

t_lsall() {  # alle Eintraege inkl. versteckter (-a ist ueberall vorhanden, -A nicht) / all entries incl. hidden
    ls -a "$1" 2>&1
}

t_rmdir() {  # leeren Ordner entfernen; ohne rmdir: "rm -r", aber NUR wenn der Ordner leer ist / remove an empty folder; without rmdir: "rm -r" ONLY if empty
    [ -d "$1" ] || return 0
    if [ "$H_rmdir" = "1" ]; then
        rmdir "$1" 2>/dev/null
        return $?
    fi
    for _e in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [ -e "$_e" ] && return 1
    done
    rm -r "${1:?}" 2>/dev/null
}

# Pruefung des Ausgabeverfahrens ohne Zeilenende (letzte Zeile ohne Zeilenende) mit einer Probedatei / self-test of line output without line ending
t_selftest_nonl() {
    _tf=${TMPDIR:-/tmp}/.mst2-nonl.$$
    for _m in $T_EMIT awk echo; do
        [ "$_m" = "awk" ] && [ "$H_awk" != "1" ] && continue
        T_NONL=$_m
        ( t_emit_nonl "a\\b" > "$_tf" ) 2>/dev/null
        if [ "$(t_size "$_tf")" = "3" ]; then rm -f "${_tf:?}"; return 0; fi
    done
    rm -f "${_tf:?}"
    T_NONL=echo
    return 1
}

# Zufallskennung aus 8 Zeichen 0-9/A-F ohne cksum, expr, uptime; Argument: eine laufende Nummer zum Vermischen.
# Die Uhr des Radios ist unzuverlaessig, die Kennung muss ohne sie auskommen.
# Random ID of 8 chars 0-9/A-F without cksum, expr, uptime; argument: a running number to mix in.
# The radio's clock is unreliable, so the ID must not depend on it.
t_makeid() {
    _seed=$(( ${RANDOM:-0} + $$ + ${1:-0} * 7919 ))
    if [ "$H_date" = "1" ]; then
        _t=$(date +%s 2>/dev/null)
        case $_t in
            ''|*[!0-9]*) _t=0 ;;
        esac
        _seed=$(( _seed + _t % 65521 ))
    fi
    _seed=$(( _seed % 65537 ))
    _id=
    _i=0
    while [ "$_i" -lt 8 ]; do
        _seed=$(( (_seed * 75 + 74 + ${RANDOM:-0}) % 65537 ))
        case $(( _seed % 16 )) in
            0) _c=0 ;; 1) _c=1 ;; 2) _c=2 ;; 3) _c=3 ;; 4) _c=4 ;; 5) _c=5 ;; 6) _c=6 ;; 7) _c=7 ;;
            8) _c=8 ;; 9) _c=9 ;; 10) _c=A ;; 11) _c=B ;; 12) _c=C ;; 13) _c=D ;; 14) _c=E ;; *) _c=F ;;
        esac
        _id="$_id$_c"
        _i=$((_i + 1))
    done
    echo "$_id"
}

# Bericht ueber die Werkzeuge; Rueckgabe 1, wenn etwas Zwingendes fehlt / tool report; returns 1 if something essential is missing
t_report() {
    echo "Werkzeuge / tools: PATH=$PATH"
    _miss=
    _have=
    for _t in $T_ESSENTIAL; do
        if [ "$(eval "echo \$H_$_t")" = "1" ]; then _have="$_have $_t"; else _miss="$_miss $_t"; fi
    done
    echo "  zwingend vorhanden / essential present:${_have:- -}"
    echo "  zwingend FEHLEND / essential MISSING:${_miss:- -}"
    _have=
    _miss=
    for _t in $T_OPTIONAL; do
        if [ "$(eval "echo \$H_$_t")" = "1" ]; then _have="$_have $_t"; else _miss="$_miss $_t"; fi
    done
    echo "  optional vorhanden / optional present:${_have:- -}"
    echo "  optional fehlend (Shell-Ersatz) / optional missing (shell fallback):${_miss:- -}"
    echo "  Ausgabeverfahren / line output: $T_EMIT (ohne Zeilenende / without line ending: $T_NONL), Vergleichsverfahren / compare method: $(t_same_method)"
    [ -z "$(t_missing_essential)" ]
}

t_missing_essential() {
    _miss=
    for _t in $T_ESSENTIAL; do
        [ "$(eval "echo \$H_$_t")" = "1" ] || _miss="$_miss $_t"
    done
    echo "$_miss"
}
