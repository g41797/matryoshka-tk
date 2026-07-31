#!/bin/bash
#
# Build matrix for the pointer-switch bug.
#
# See design/llvm-pointer-switch-bug-001.md.
#
# Builds one source file across:
# - both backends: -fllvm, -fno-llvm
# - four optimize levels
# - native plus three cross targets
#
# Native rows are built and run. Cross rows are built only.
#
# No set -e. Failures are the output.

cd "$(dirname "$0")/../.."

# The compiler segfaults on some combinations. Do not write core dumps.
ulimit -c 0

REPRO="${1:-design/llvm-pointer-switch-repro.zig}"
# Seconds per build. Some combinations hang the compiler.
TIMEOUT="${TIMEOUT:-60}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Each can be narrowed from the environment, space separated. Example:
#   TARGETS=x86_64-windows bash kitchen/tools/build_repro_matrix.sh
read -r -a BACKENDS <<< "${BACKENDS:--fllvm -fno-llvm}"
read -r -a LEVELS <<< "${LEVELS:-Debug ReleaseSafe ReleaseFast ReleaseSmall}"
read -r -a TARGETS <<< "${TARGETS:-native x86_64-macos aarch64-macos x86_64-windows}"

# The workaround: same dispatch, if/else chain instead of switch.
CHAIN="$WORK/chain.zig"
cat > "$CHAIN" <<'EOF'
const std = @import("std");
var ta: u8 = 0;
var tb: u8 = 0;
const TA: *const anyopaque = &ta;
const TB: *const anyopaque = &tb;
var n: usize = 0;
pub fn byTag(tag: *const anyopaque) void {
    if (tag == TA) {
        n += 1;
    } else if (tag == TB) {
        n += 2;
    } else {
        n += 3;
    }
}
pub fn main() void {
    byTag(TA);
    std.debug.print("{}\n", .{n});
}
EOF

run_matrix() {
    local src="$1"
    local label="$2"
    local fails=0
    local runs=0

    echo
    echo "=============================================================="
    echo "$label"
    echo "source: $src"
    echo "=============================================================="
    printf '%-16s %-10s %-14s %s\n' "target" "backend" "optimize" "result"
    printf -- '--------------------------------------------------------------\n'

    for target in "${TARGETS[@]}"; do
        for backend in "${BACKENDS[@]}"; do
            for level in "${LEVELS[@]}"; do
                runs=$((runs + 1))
                local out="$WORK/bin_$runs"
                local log="$WORK/log_$runs"
                local targs=()
                [ "$target" != "native" ] && targs=(-target "$target")

                # -k: SIGKILL 10s after SIGTERM. A hung zig ignores SIGTERM.
                timeout -k 10 --foreground "$TIMEOUT" \
                    zig build-exe "$src" "$backend" "-O$level" \
                    "${targs[@]}" -femit-bin="$out" \
                    > "$log" 2>&1
                local rc=$?

                local result
                if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
                    result="TIMEOUT after ${TIMEOUT}s"
                    fails=$((fails + 1))
                elif [ $rc -ge 128 ]; then
                    result="COMPILER CRASH: signal $((rc - 128))"
                    fails=$((fails + 1))
                elif [ $rc -eq 0 ]; then
                    if [ "$target" = "native" ]; then
                        local printed
                        printed="$("$out" 2>&1)"
                        if [ "$printed" = "1" ]; then
                            result="ok, ran, printed 1"
                        else
                            result="BUILT BUT WRONG OUTPUT: '$printed'"
                            fails=$((fails + 1))
                        fi
                    else
                        result="ok, built"
                    fi
                else
                    local msg
                    msg="$(grep -m1 . "$log" | cut -c1-90)"
                    [ -z "$msg" ] && msg="no message, exit $rc"
                    case "$msg" in
                        *"not available"*|*"unsupported"*|*"does not support"*|*"unable to"*)
                            result="n/a: $msg" ;;
                        *)
                            result="FAIL: $msg"
                            fails=$((fails + 1)) ;;
                    esac
                fi

                printf '%-16s %-10s %-14s %s\n' \
                    "$target" "$backend" "$level" "$result"
            done
        done
    done

    echo
    echo "$label: $fails failure(s) out of $runs builds"
    return 0
}

date
echo "zig: $(zig version)"

run_matrix "$REPRO" "MATRIX 1 — switch on a runtime pointer"
run_matrix "$CHAIN" "MATRIX 2 — if/else chain (the workaround)"

date
