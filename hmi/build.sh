#!/bin/sh
# Baut das HMI-Buendel unter Linux/macOS (Gegenstueck zu build.ps1).
# Builds the HMI bundle on Linux/macOS (counterpart of build.ps1).
#
# Aufruf / Usage:  sh hmi/build.sh <MIBHMI.jar> [<JDK-8-Verzeichnis | JDK 8 directory>]
# Das JDK muss Version 8 sein (Quelltext-Stufe 1.3 wird nur dort unterstuetzt).
# The JDK must be version 8 (source level 1.3 is only supported there).
set -eu
MIBHMI="${1:?MIBHMI.jar fehlt / missing}"
JDK="${2:-${JAVA_HOME:-}}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "$JDK" ]; then JAVAC="$JDK/bin/javac"; JAR="$JDK/bin/jar"; else JAVAC=javac; JAR=jar; fi
"$JAVAC" -version 2>&1 | grep -q '1\.8\.' || { echo "JDK 8 erforderlich / JDK 8 required"; exit 1; }
OUT="$HERE/build"
rm -rf "$OUT"
mkdir -p "$OUT/classes"
"$JAVAC" -source 1.3 -target 1.3 -nowarn -encoding UTF-8 -cp "$MIBHMI" -d "$OUT/classes" "$HERE"/src/mst2/eu/cluster/*.java
"$JAR" cfm "$OUT/mst2-eu-rgi-hmi.jar" "$HERE/manifest.mf" -C "$OUT/classes" .
echo "$OUT/mst2-eu-rgi-hmi.jar"
