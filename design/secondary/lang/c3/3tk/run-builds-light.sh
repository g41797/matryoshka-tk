#!/usr/bin/env bash
#
# The LIGHT run. One build, one test suite, go/no-go after a source edit.
#
# THIS IS NOT THE VERIFICATION. `run-builds.sh` is, and nothing here replaces
# it: this script runs ONE of its four builds and NONE of its negatives. A
# stage reports its result from `run-builds.sh`, always. This one exists
# because that takes minutes and an edit-compile loop cannot afford them.
#
# What it proves:   the library compiles and every test passes, in a checked,
#                   unoptimized build.
# What it does NOT: the three other builds; that a contract violation aborts
#                   where checks are live and runs to the end where they are
#                   not; that the compile-time negatives still refuse; the
#                   Part 17.2 layering. D6's whole point is that behaviour
#                   DIFFERS between builds, and one build cannot see it.
#
# So: green here means "keep going". It never means "done".
#
# Usage:  ./run-builds-light.sh [dir]      dir defaults to this script's own directory
# Exit 0 only if the library builds and the suite is green.

set -u

# Same argument handling as run-builds.sh, and the `|| exit` is not decoration:
# there is no `set -e`, so without it a failed cd would run the build in
# whatever directory the caller happened to be in.
ROOT=${1:-}
[ -n "$ROOT" ] || ROOT=$(dirname "$0")
cd "$ROOT" || { echo "no such directory: $ROOT" >&2; exit 2; }

C3C=${C3C:-c3c}
PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }

# The one mode, and it is the cheapest useful one: checks live, no optimizer.
#
# It is spelled `--safe=yes -O0` and not left to default for the reason
# run-builds.sh records at length — `-O2` and above turn safe mode off
# implicitly, so the flags are always explicit on both sides here.
FLAGS="--safe=yes -O0"

echo "== light run: safe -O0  ($FLAGS) =="
echo "   one build of four, no negatives. NOT the verification."
echo

if $C3C build mtk $FLAGS >"$TMP/build.log" 2>&1; then
    ok "library builds"
else
    bad "library builds"; sed 's/^/        /' "$TMP/build.log"
fi

if $C3C test $FLAGS >"$TMP/test.log" 2>&1; then
    N=$(grep -oE '[0-9]+ tests run' "$TMP/test.log" | head -1)
    ok "test suite green (${N:-unknown})"
else
    bad "test suite green"
    # The failing test by name, not the last 30 lines of a passing tail.
    # `c3c test` prints every test it ran, so the end of the log is whatever
    # happened to run last — which is almost never the one that broke.
    if grep -qE "FAIL|Error" "$TMP/test.log"; then
        grep -E "FAIL|Error" "$TMP/test.log" | head -20 | sed 's/^/        /'
    else
        tail -30 "$TMP/test.log" | sed 's/^/        /'
    fi
fi

echo
echo "=========================================="
printf 'passed %s, failed %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "go — now run ./run-builds.sh before reporting anything"
