#!/usr/bin/env bash
#
# 3TK-9. The test suite under ThreadSanitizer and AddressSanitizer.
#
# SEPARATE FROM run-builds.sh ON PURPOSE. That script's only requirement is
# `c3c`, and it has to stay that way: it is what a cold session and any other
# machine runs. This one needs a C compiler that ships sanitizer runtimes, and
# on this machine that is clang, not cc — see the note below. A hard dependency
# on clang does not belong in the gate.
#
# Why --cc clang. c3c has --sanitize=address|memory|thread and passes the flag
# to the system linker, which is `cc` by default. On Fedora the sanitizer
# runtimes ship in separate packages that are not installed, so `cc` fails to
# link with `cannot find /usr/lib64/libtsan.so.2.0.0`. That is not a c3c defect:
# plain `cc -fsanitize=thread` on a two-line C file fails identically. clang
# carries its own runtimes, and c3c's --cc points the link at it. No install, no
# root, no change to the machine.
#
# Usage:  ./run-sanitizers.sh [dir]  dir defaults to this script's own directory
# Exit 0 only if every sanitizer run is clean.

set -u

# The directory to run against. Optional.
#
#   ./run-sanitizers.sh            -> the directory this script lives in, as before
#   ./run-sanitizers.sh <dir>      -> <dir> instead
#
# An empty argument is the same as none. `set -u` is on, hence ${1:-}.
#
# The `|| exit` is not decoration. There is no `set -e` here, so without it a
# failed cd would let every command below run in whatever directory the caller
# happened to be in.
ROOT=${1:-}
[ -n "$ROOT" ] || ROOT=$(dirname "$0")
cd "$ROOT" || { echo "no such directory: $ROOT" >&2; exit 2; }

C3C=${C3C:-c3c}
CC=${SAN_CC:-clang}
PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }

if ! command -v "$CC" >/dev/null 2>&1; then
    echo "SKIP: '$CC' not on the path."
    echo "      The sanitizers need a C compiler that ships their runtimes."
    echo "      Set SAN_CC=<compiler> if yours is named differently."
    echo "      This is a skip and not a pass: nothing was verified."
    exit 2
fi

echo "== c3c =="
$C3C --version | head -3
echo "== linker for the sanitized builds: $CC =="
echo

run_san() {
    local san="$1" flags="$2" label="$3"
    local log
    log=$(mktemp)

    if ! timeout 900 $C3C test $flags --sanitize="$san" --cc "$CC" >"$log" 2>&1; then
        # A sanitizer finding and a compile failure both exit non-zero, and they
        # are not the same thing. 3TK-8's lesson, applied here before it costs
        # anything: say which one happened.
        if grep -q "Error:" "$log"; then
            bad "$label — DID NOT BUILD (not a sanitizer finding)"
        else
            bad "$label — sanitizer reported a problem"
        fi
        grep -E "WARNING: ThreadSanitizer|ERROR: AddressSanitizer|SUMMARY:|Error:" "$log" | head -12 | sed 's/^/        /'
        rm -f "$log"
        return
    fi

    local warns
    warns=$(grep -cE "WARNING: ThreadSanitizer|ERROR: AddressSanitizer" "$log" || true)
    if [ "$warns" != "0" ]; then
        bad "$label — $warns finding(s) despite a zero exit"
        grep -E "SUMMARY:" "$log" | head -8 | sed 's/^/        /'
    else
        ok "$label — clean ($(grep -oE '[0-9]+ tests run' "$log" | head -1))"
    fi
    rm -f "$log"
}

# Thread first: it is the one that found something. 3TK-9's four races were all
# in TestHooks, never in src/ — Part 12.3 says a hook protects its own state,
# and the toolkit's own tests were the application that did not.
run_san thread  "--safe=yes -O0" "thread  safe -O0"
run_san thread  "--safe=no  -O3" "thread  fast -O3"
run_san address "--safe=yes -O0" "address safe -O0"

echo
echo "=========================================="
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ] && echo "sanitizers clean" || echo "SANITIZER FINDINGS"
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
