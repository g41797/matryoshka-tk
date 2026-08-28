#!/usr/bin/env bash
#
# 3TK-6 verification, as 3TK-11 left it. The four builds of
# 3tk-porting-proposal-004.md section 7.2,
# every one of them, plus the negative programs that prove D6 was applied.
#
# A stage that reports three builds has not run.
#
# Usage:  ./run-builds.sh [dir]      dir defaults to this script's own directory
# Exit 0 only if every build, every test and every negative behaves as specified.

set -u

# The directory to run against. Optional.
#
#   ./run-builds.sh            -> the directory this script lives in, as before
#   ./run-builds.sh <dir>      -> <dir> instead
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
PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()   { PASS=$((PASS+1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }

# The four builds. Name, then the flags.
# NOTE, and it is a finding of 3TK-6 rather than a detail:
#
#   `-O2` and above turn safe mode OFF implicitly. `c3c ... -O3` reports
#   SAFE_MODE=false. So the proposal's "safe, optimized" build cannot be
#   spelled `-O3`; it must be `--safe=yes -O3`, or it silently becomes the
#   fast build and tests nothing the fast build does not already test.
#
#   Measured on c3c 0.8.3:
#     <default>       SAFE_MODE=true   OPT=O0
#     -O0             SAFE_MODE=true   OPT=O0
#     -O1             SAFE_MODE=true   OPT=O2
#     -O2             SAFE_MODE=false  OPT=O2
#     -O3             SAFE_MODE=false  OPT=O2
#     --safe=yes -O3  SAFE_MODE=true   OPT=O2
#     --safe=no  -O0  SAFE_MODE=false  OPT=O0
#
MODES=("safe -O0::--safe=yes -O0"
       "safe -O3::--safe=yes -O3"
       "fast -O0::--safe=no -O0"
       "fast -O3::--safe=no -O3")

# A runtime negative aborts where the checks are live and exits 0 where they are not.
RUNTIME_NEGATIVES=(overwrite_slot create_into_full_slot insert_twice_same_queue insert_linked_item self_move wrong_type_must duplicate_pool_tags pool_unknown_identity)

# A TIER 1 negative aborts in EVERY mode, including --safe=no -O3. Part 11.12 is
# the one precondition the specification refuses to soften, and this is the only
# shape in the suite whose expected behaviour does not change with the build.
#
# 3TK-53 added `release_while_receiving`. Part 11.12 has two halves, and the
# suite tested one of them: an OPEN mailbox cannot be released, and neither can
# a CLOSED one that is not yet quiet. The second half is the one a real program
# gets wrong, because closing looks like it finished something.
#
# 3TK-54 added the pool's four. The mailbox needs one program for the second
# half and the pool needs four, because Part 12.3 forces the mutex open across
# every call into a hook: a pool can be closed and not quiet in four distinct
# places, and each one is a different site rather than a different schedule of
# the same site.
#
#   release_not_quiet_pool      a get_wait woken by the close, not yet returned
#   release_during_on_put       a put inside on_put, about to re-take the mutex
#   release_during_on_close     close's own hook, after CLOSED is published
#   release_with_straggler_put  the SECOND on_close, called from inside put
TIER1_NEGATIVES=(release_open_mailbox release_while_receiving
                 release_open_pool release_not_quiet_pool
                 release_during_on_put release_during_on_close
                 release_with_straggler_put)

# A compile-time negative never compiles, in any mode, and its message must name the type.
declare -A NOCOMPILE_EXPECT=(
  [nocompile_no_inner]="NotAnItem"
  [nocompile_two_inners]="TwoInners"
  [nocompile_managed_no_allocator]="mtk::helper"
  [nocompile_managed_two_allocators]="TwoAllocators"
)

echo "== c3c =="
$C3C --version | head -4
echo

for entry in "${MODES[@]}"; do
    NAME=${entry%%::*}
    FLAGS=${entry##*::}
    CHECKED=0
    case "$FLAGS" in *--safe=no*) CHECKED=0 ;; *) CHECKED=1 ;; esac
    # explicit on both sides: never infer the mode from the -O level

    echo "== build: $NAME  ($FLAGS) =="

    # --- the library builds
    if $C3C build mtk $FLAGS >"$TMP/build.log" 2>&1; then
        ok "library builds"
    else
        bad "library builds"; sed 's/^/        /' "$TMP/build.log"
    fi

    # --- the test suite is green
    if $C3C test $FLAGS >"$TMP/test.log" 2>&1; then
        N=$(grep -oE '[0-9]+ tests run' "$TMP/test.log" | head -1)
        ok "test suite green (${N:-unknown})"
    else
        bad "test suite green"; tail -30 "$TMP/test.log" | sed 's/^/        /'
    fi

    # --- the runtime negatives
    #
    # Compile and run are judged SEPARATELY, and that is not a refinement.
    # `compile-run` reports a compile failure the same way it reports a
    # SIGABRT — a non-zero exit — so a negative that stopped compiling would be
    # read as a negative that aborted, and would pass forever having proved
    # nothing. That is exactly what happened to release_open_pool: `Msg.typeid`
    # does not compile on c3c 0.8.3, and the tier 1 site of Part 11.12 went
    # unexercised while the suite reported it green.
    for n in "${RUNTIME_NEGATIVES[@]}"; do
        if ! $C3C compile $FLAGS -o "$TMP/$n.bin" "negative/common.c3" "negative/$n.c3" src/*.c3 \
            >"$TMP/$n.build.log" 2>&1; then
            bad "negative $n DOES NOT COMPILE — it proves nothing until it does"
            tail -8 "$TMP/$n.build.log" | sed 's/^/        /'
            continue
        fi
        $C3C compile-run $FLAGS -o "$TMP/$n" "negative/common.c3" "negative/$n.c3" src/*.c3 \
            >"$TMP/$n.log" 2>&1
        RC=$?
        if [ "$CHECKED" = "1" ]; then
            # SIGABRT through the shell is 134; c3c compile-run may report it differently
            if [ "$RC" -ne 0 ] || grep -qi "assert\|abort\|panic" "$TMP/$n.log"; then
                ok "negative $n aborts"
            else
                bad "negative $n did NOT abort in a checking build"
                tail -5 "$TMP/$n.log" | sed 's/^/        /'
            fi
        else
            if [ "$RC" -eq 0 ] && grep -q "no check" "$TMP/$n.log"; then
                ok "negative $n runs to the end"
            else
                bad "negative $n did not run to the end in a fast build (rc=$RC)"
                tail -8 "$TMP/$n.log" | sed 's/^/        /'
            fi
        fi
    done

    # --- the tier 1 negatives: abort in EVERY mode
    for n in "${TIER1_NEGATIVES[@]}"; do
        if ! $C3C compile $FLAGS -o "$TMP/$n.bin" "negative/common.c3" "negative/$n.c3" src/*.c3 \
            >"$TMP/$n.build.log" 2>&1; then
            bad "TIER 1 $n DOES NOT COMPILE — the one unsoftenable precondition is untested"
            tail -8 "$TMP/$n.build.log" | sed 's/^/        /'
            continue
        fi
        $C3C compile-run $FLAGS -o "$TMP/$n" "negative/common.c3" "negative/$n.c3" src/*.c3 \
            >"$TMP/$n.log" 2>&1
        RC=$?
        if grep -q "SOFTENED" "$TMP/$n.log"; then
            bad "TIER 1 $n did NOT abort — Part 11.12 has been softened"
        elif [ "$RC" -ne 0 ] || grep -qi "assert\|abort\|panic" "$TMP/$n.log"; then
            ok "tier 1 $n aborts (as it must in every mode)"
        else
            bad "TIER 1 $n did not abort and said nothing"
            tail -5 "$TMP/$n.log" | sed 's/^/        /'
        fi
    done

    # --- the compile-time negatives, in every mode
    for n in "${!NOCOMPILE_EXPECT[@]}"; do
        WANT=${NOCOMPILE_EXPECT[$n]}
        if $C3C compile $FLAGS -o "$TMP/$n" "negative/$n.c3" src/*.c3 >"$TMP/$n.log" 2>&1; then
            bad "$n compiled, and it must not"
        elif grep -qF "$WANT" "$TMP/$n.log"; then
            ok "$n refused, message names '$WANT'"
        else
            bad "$n refused, but the message does not name '$WANT'"
            tail -5 "$TMP/$n.log" | sed 's/^/        /'
        fi
    done
    echo
done

# --- Part 17.2, the layering, once rather than per build ---
#
# "Both are built ON the intrusive layer, with no privileged access to it.
#  Every crossing they perform is a crossing an application could write."
#
# Part 17.3 calls this the test of the design, so it is a test.
#
# The strongest available form, and C3 gives it for free: `mailbox.c3` and
# `pool.c3` declare `module mtk::mailbox` and `module mtk::pool`, and a
# submodule CANNOT see its parent's `@private` declarations. So the layering is
# enforced by the compiler, not by this grep. The grep guards the declaration
# itself, which is the thing a careless edit would undo.
echo "== Part 17.2: the layering =="
for f in mailbox pool; do
    if grep -qE "^module mtk::$f;" "src/$f.c3"; then
        ok "src/$f.c3 is a submodule, so mtk's private declarations are out of reach"
    else
        bad "src/$f.c3 is not 'module mtk::$f' — Part 17.2 is no longer compiler-enforced"
    fi
done
# `unlink_no_repair` went with the redesign — the queue and the stack have no
# unrepaired removal left to reach for. What remains reachable is the insert
# guard and the link field itself, and a container that touched either would be
# maintaining chains by hand instead of calling the surface.
#
# The field is `link` since 3TK-18; it was `next`.
#
# The SPELLING of a link write changed with 3TK-21. The inner is one `any`, so
# a write is `h.repoint_to(x)` or a rebuild through `any_make`, where it used to
# be `h.link = x`. All three are grepped: `.link =` still catches a hand-written
# assignment of the whole field, and `any_make` catches the rebuild that would
# get around `repoint_to`. 3TK-18 hit this same line and its log row says what
# happens when the spelling moves and the grep does not — the check goes on
# printing ok for ever.
if grep -nE '(@guard_insert|\.repoint_to|any_make|\.link[[:space:]]*=)' src/mailbox.c3 src/pool.c3 >/dev/null 2>&1; then
    bad "a container reaches around the InnerQueue/InnerStack surface"
else
    ok "no container reaches around the InnerQueue/InnerStack surface"
fi
echo

echo "=========================================="
printf 'passed %s, failed %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "all four builds green"
