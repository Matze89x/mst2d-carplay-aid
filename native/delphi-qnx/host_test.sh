#!/bin/sh
# Logic test of the rejection guard on the host (no radio, no QNX). Needs clang with an host target.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${OUT:-/tmp/reject_guard_host}
${CLANG:-clang} -std=gnu99 -O1 -ffreestanding -nostdlib -static -fno-stack-protector -fno-builtin -Wall -Wextra -Werror \
  -I"$HERE/include" -I"$HERE/../rgi/include" -o "$OUT" "$HERE/test/reject_guard_host.c" "$HERE/../rgi/src/dcc_identify.c" "$HERE/../rgi/src/dcc_rgi.c" "$HERE/../rgi/src/dcc_log.c" "$HERE/../rgi/src/dcc_route.c"
"$OUT"
