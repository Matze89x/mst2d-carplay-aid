#!/bin/sh
# Modellpruefung des HMI-Buendels unter Linux/macOS (Gegenstueck zu test.ps1).
# Model checks of the HMI bundle on Linux/macOS (counterpart of test.ps1).
# Aufruf / Usage:  sh hmi/test.sh [<JDK-8-Verzeichnis | JDK 8 directory>]
set -eu
JDK="${1:-${JAVA_HOME:-}}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "$JDK" ]; then JAVAC="$JDK/bin/javac"; JAVA="$JDK/bin/java"; else JAVAC=javac; JAVA=java; fi
"$JAVAC" -version 2>&1 | grep -q '1\.8\.' || { echo "JDK 8 erforderlich / JDK 8 required"; exit 1; }
OUT="$HERE/build/test-classes"
rm -rf "$OUT"
mkdir -p "$OUT"
"$JAVAC" -source 1.3 -target 1.3 -nowarn -encoding UTF-8 -d "$OUT" \
  "$HERE/test/de/vw/mib/asl/api/navbap/INavLaneGuidanceDataNavBap.java" \
  "$HERE/src/mst2/eu/cluster/Snapshot.java" \
  "$HERE/src/mst2/eu/cluster/LaneData.java" \
  "$HERE/src/mst2/eu/cluster/Maneuver.java" \
  "$HERE/test/mst2/eu/cluster/Check.java"
"$JAVA" -cp "$OUT" mst2.eu.cluster.Check
