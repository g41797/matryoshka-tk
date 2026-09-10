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
RUNTIME_NEGATIVES=(overwrite_slot create_into_full_slot insert_twice_same_queue insert_linked_outer self_move wrong_type_must duplicate_pool_tags pool_unknown_identity
                   unstamped_insert unstamped_crossing
                   unstamped_inner wrong_type_inner)

# 3TK-65 added the last two. Part 5.2 asserts the identity at BOTH boundaries and
# the two programs are not variants of one another: `unstamped_insert` reaches
# `@guard_insert` and never reaches a crossing, `unstamped_crossing` fills the
# Slot by hand and so never reaches a guard. A suite with one of them would go
# green with the other boundary unguarded.
#
# 3TK-75 added the two after them, and they are the third boundary rather than a
# third variant. `C-1` stopped `OuterHelper.inner` writing the identity and made
# it verify one, so the crossing OUT is now guarded too: `unstamped_inner` gives
# it an outer that was never stamped, `wrong_type_inner` one stamped as another
# type. The second is the half no stamp could ever have caught — the old
# `inner()` would have re-stamped it and agreed with itself afterwards.

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
#
# 3TK-64 RETIRED TWO OF THESE, and the retirement is the stage, not a loss of
# coverage. `nocompile_managed_no_allocator` and `nocompile_managed_two_allocators`
# asserted that an outer without exactly one `Allocator` field does not compile.
# There is no allocator-field concept any more — the allocator is passed to
# `create` and `release` — so both of those outers must now compile AND RUN.
# The proof moved to `test/t_helper.c3`, where it is a positive test:
# `an_outer_needs_no_allocator_field` and `two_allocator_fields_are_the_outers_business`.
#
# 3TK-74 ADDED TWO, and they are the other direction of the same idea: the first
# two assert that a type WITHOUT an `Inner` is refused, these two that a type
# with one but without its hooks is refused. `B-1` made `init` and `finish`
# required, and the whole point of the change is that a misspelled hook stopped
# being silent — so `nocompile_no_init` spells it `initialize`, the near miss
# `helper.c3`'s module block names, rather than omitting it.
#
# What is grepped for here is the `$assert` message and not a type name. The
# message is a constant string, so it cannot carry the offending type; the
# compiler names the CALL SITE instead, which is the half a user needs. The
# other direction of the check — that it stays quiet for a type that declares
# both hooks — is the test suite, green in all four builds.
declare -A NOCOMPILE_EXPECT=(
  [nocompile_no_inner]="NotAnItem"
  [nocompile_two_inners]="TwoInners"
  [nocompile_no_init]="Outer.init"
  [nocompile_no_finish]="Outer.finish"
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
#
# 3TK-pre-65 REWROTE IT FOR SIX NAMES. Part 4.5: the module line IS the design,
# so the check asserts the whole list rather than two of it — every file
# declares exactly what the design says it declares, and no file declares
# anything else. `helper.c3` and `queue.c3` went back to modules of their own,
# and a check that knew only `mailbox` and `pool` would have gone red on the
# correct change.
#
# 3TK-70 REWROTE IT AGAIN, FOR ELEVEN NAMES IN SIX FILES, and the shape had to
# change with the count: a file is no longer one module. Each of `inner.c3`,
# `queue.c3` and `mailbox.c3` carries two sections and `pool.c3` carries three,
# so what is asserted per file is the ORDERED LIST of its module lines. Order
# is part of it: `pool.c3` opens on `mtk::pool::hooks` the way `atomic.c3` opens
# on `std::atomic::types`, and a section that drifted to the wrong place would
# take its imports with it.
#
# This is the trap `3TK-pre-65` and `3TK-67` both hit, and it is deliberate: a
# correct module change goes RED here first, and the list moves in the same pass.
echo "== Part 17.2: the layering, and Part 4.5: the module list =="
declare -A EXPECT_MODULE=(
    [mtk]='module mtk;'
    [inner]='module mtk::inner;|module mtk::inner::internal;'
    [queue]='module mtk::queue;|module mtk::queue::internal;'
    [helper]='module mtk::helper <Outer>;'
    [mailbox]='module mtk::mailbox;|module mtk::mailbox::internal;'
    [pool]='module mtk::pool::hooks;|module mtk::pool;|module mtk::pool::internal;'
)
for f in mtk inner queue helper mailbox pool; do
    want=${EXPECT_MODULE[$f]}
    have=$(grep -hoE '^module [A-Za-z_:]+( <[A-Za-z_]+>)?( @[a-z]+)?;' "src/$f.c3" | paste -sd'|' -)
    if [ "$have" = "$want" ]; then
        ok "src/$f.c3 declares '$(echo "$want" | tr '|' ' ')'"
    else
        bad "src/$f.c3 declares '$have', not '$want' — the module list has drifted"
    fi
done
# Nothing beyond the list. A twelfth module name in `src/` is a partition the
# design does not describe, and the visibility of everything in it is unruled.
UNEXPECTED=$(grep -hoE '^module [A-Za-z_:]+( <[A-Za-z_]+>)?( @[a-z]+)?;' src/*.c3 | sort -u \
    | grep -vxE 'module mtk;|module mtk::helper <Outer>;|module mtk::(inner|queue|mailbox|pool);|module mtk::(inner|queue|mailbox|pool)::internal;|module mtk::pool::hooks;')
if [ -z "$UNEXPECTED" ]; then
    ok "src/ declares no module outside the list of eleven"
else
    bad "src/ declares a module the list does not carry: $(echo "$UNEXPECTED" | tr '\n' ' ')"
fi
# --- Part 4.4a, the partition of `module mtk`, and it is testable ---
#
# Ruled by the owner, 2026-09-07: the first part of `inner.c3` is what a user
# has no other way to write, the second part is what `OuterHelper` does for
# them. `examples/` is the user's voice — `test/` is white-box and exempt by
# design — so the partition is a fact about `examples/` and this checks it.
#
# The banners are asserted FIRST. If a part is renamed, this check must not
# quietly fall back to grepping nothing, which is the same guard the stack
# banner gets above.
echo "== Part 4.4a: the partition of module mtk =="
PARTITION_OK=1
for banner in '^// Part 2 of 2: public, and not yours' '^module mtk::inner::internal;'; do
    if grep -qE "$banner" src/inner.c3; then :; else
        bad "src/inner.c3 has lost the banner '$banner' — the partition is unmarked"
        PARTITION_OK=0
    fi
done
[ $PARTITION_OK -eq 1 ] && ok "src/inner.c3 carries the part banners the partition is written in"

# The second part, by name. Two examples name a crossing on purpose and are
# listed here rather than silently skipped: 010 asserts that `create` wrote an
# identity, and 012's whole subject is that the free form and the method form
# give the same answer. Any THIRD example is a user reaching past the helper,
# and either the example is wrong or the partition is.
INTERNAL='inner::internal::(to_inner|from_inner|must_from_inner|from_slot|must_from_slot|move_from_slot|is_mine|stamp|is_linked|reset|inner_offset)\b|\.(repoint_to|points_to)[[:space:]]*\('
ALLOWED='examples/010-no_raw_allocator_call.c3|examples/012-type_crossing.c3'
REACHING=$(grep -rEn "$INTERNAL" examples/*.c3 | grep -vE "^[^:]*:[0-9]+:[[:space:]]*//" \
    | grep -vE "^($ALLOWED):" | cut -d: -f1 | sort -u)
if [ -z "$REACHING" ]; then
    ok "no example reaches past the helper into the second part of module mtk"
else
    bad "an example calls what the helper is there for: $(echo "$REACHING" | tr '\n' ' ')"
fi

# --- Rule 2 and Rule 3: the internal module, and the marker ---
#
# 3TK-70 MOVED THE TRUTH FROM POSITION TO MODULE. 3TK-67 keyed this check on
# where a declaration sits relative to `// For internal usage - everything below
# this line.`, and that was the strongest form available while a file was one
# module. It is not any more: each of `inner.c3`, `queue.c3`, `mailbox.c3` and
# `pool.c3` now carries an `mtk::X::internal` section, because `c3c docgen`
# groups by module and by nothing else and a page wants one subject.
#
# The module is strictly stronger than the position. A banner is a comment: it
# can be renamed, duplicated or deleted, and the check has to assert its
# presence first to stop itself quietly grepping nothing. A module section is
# the compiler's own partition — a declaration cannot fail to be in one, and
# nothing between the module line and the next one can be outside it.
#
# THE BANNER STAYS, and it stays as a section header for a human reading the
# file. It is asserted below, by name, exactly as before. What changed is that
# it no longer decides anything.
#
# The check still runs BOTH WAYS: every declaration in an `::internal` section
# opens its block with the marker, and no declaration outside one does. The
# marker is what crosses to the docs site; docgen publishes no file structure
# and no `//` comment, so a reader on the generated page has the marker and the
# page title and nothing else.
echo "== Rule 2, Rule 3: the internal module and the marker =="
INTERNAL_BANNER='// For internal usage - everything below this line.'
MARKERS=$(${PYTHON:-python3} - src/*.c3 <<'PY_END'
import re, sys

MARKER = 'For internal usage.'
DECL = re.compile(r'^(fn|macro|struct|typedef|const|alias|enum|interface|faultdef)\b')
MODULE = re.compile(r'^module[ \t]+([A-Za-z_][A-Za-z_0-9:]*)')


def block_head(lines, i):
    """The first content line of the `<* *>` block above the declaration at `i`.

    None when there is no block. Any `//` line between the block and the
    declaration is stepped over, the same way `doc_blocks.py` does.
    """
    j = i - 1
    while j >= 0 and lines[j].startswith('//'):
        j -= 1
    if j < 0 or lines[j].strip() != '*>':
        return None
    k = j
    while k >= 0 and lines[k].strip() != '<*':
        k -= 1
    if k < 0:
        return None
    body = [x.strip() for x in lines[k + 1:j]]
    return body[0] if body else ''


bad = []
for p in sys.argv[1:]:
    lines = open(p).read().splitlines()
    mod = None
    sections = 0
    for i, l in enumerate(lines):
        m = MODULE.match(l)
        if m:
            mod = m.group(1)
            if mod.endswith('::internal'):
                sections += 1
            continue
        if not DECL.match(l):
            continue
        marked = block_head(lines, i) == MARKER
        internal = mod is not None and mod.endswith('::internal')
        if internal and not marked:
            bad.append('%s:%d:in-an-internal-module-and-unmarked' % (p, i + 1))
        elif marked and not internal:
            bad.append('%s:%d:marked-and-outside-an-internal-module' % (p, i + 1))
    if sections > 1:
        bad.append('%s:has-%d-internal-sections' % (p, sections))
print(' '.join(bad))
PY_END
)
if [ -z "$MARKERS" ]; then
    ok "every declaration in an internal module is marked, and none outside one is"
else
    bad "the internal partition has drifted: $MARKERS"
fi

# The banner, per file, asserted by name. It is no longer the truth, so a
# renamed banner can no longer make the check above grep nothing — but it is
# still the only section header a maintainer reading the file gets, and it is
# where the reason those declarations are public is stated once.
for f in inner queue mailbox pool; do
    if grep -qxF "$INTERNAL_BANNER" "src/$f.c3"; then
        ok "src/$f.c3 carries the internal banner"
    else
        bad "src/$f.c3 has lost its internal banner — its internal section is unheaded"
    fi
done
# `mtk.c3` and `helper.c3` have none, because every declaration in them is the
# user surface. A banner appearing in either is a design change, not a tidy.
for f in mtk helper; do
    if grep -qxF "$INTERNAL_BANNER" "src/$f.c3"; then
        bad "src/$f.c3 has grown an internal banner — every declaration in it is the user surface"
    else
        ok "src/$f.c3 declares nothing internal"
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
#
# 3TK-62 NARROWED IT, and the narrowing is the design, not a suppression.
# `stack.c3` was deleted and `InnerStack` moved to the end of `pool.c3`, inside
# `module mtk::pool`. The stack IS the surface, so it uses `@guard_insert` and
# `.repoint_to` by right. This grep works on `pool.c3` as a FILE, so it would
# report the surface as a container reaching around itself and go red on a
# correct change.
#
# So `pool.c3` is cut at the stack's banner and only the container half — every
# line above it, which is all of `_Pool` — is grepped. The banner's presence is
# asserted first: if it is ever renamed, this check must NOT quietly fall back
# to grepping the whole file or nothing at all. Part 4.5 of the boundaries
# document records that this grep is the only enforcement there is, because
# `@private` is ignored on method declarations, so it must stay one.
STACK_BANNER='^// The intrusive stack — private to the pool'
if ! grep -qE "$STACK_BANNER" src/pool.c3; then
    bad "src/pool.c3 has no stack banner — the layering grep cannot be narrowed correctly"
else
    ok "src/pool.c3 carries the stack banner the layering grep cuts at"
fi
# awk, not sed: the banner contains `//`, which collides with sed's own address
# delimiter — the expression errors out, the half comes out EMPTY, and the grep
# prints ok for ever. That is the exact failure the paragraph above warns about,
# and it happened once during 3TK-62 before this line was rewritten.
CONTAINER_HALF=$(awk -v b="$STACK_BANNER" '$0 ~ b {exit} {print}' src/pool.c3)
if [ "$(printf '%s\n' "$CONTAINER_HALF" | wc -l)" -lt 100 ]; then
    bad "the container half of src/pool.c3 came out empty — the layering grep is checking nothing"
else
    ok "the container half of src/pool.c3 is what the layering grep sees"
fi
if printf '%s\n' "$CONTAINER_HALF" | grep -nE '(@guard_insert|\.repoint_to|any_make|\.link[[:space:]]*=)' >/dev/null 2>&1 \
   || grep -nE '(@guard_insert|\.repoint_to|any_make|\.link[[:space:]]*=)' src/mailbox.c3 >/dev/null 2>&1; then
    bad "a container reaches around the InnerQueue/InnerStack surface"
else
    ok "no container reaches around the InnerQueue/InnerStack surface"
fi
# --- Part 5.2: the identity is checked at BOTH boundaries ---
#
# 3TK-65. Eight call sites, and a count rather than a list of files, because
# the failure this guards against is a site being DELETED, not a site being
# wrong. The four crossings of `helper.c3` are the late boundary and the two
# `@guard_insert` bodies are the early one; a suite that only ran the negatives
# would still go green with sites missing, since two programs cannot reach
# eight of them.
#
# THE CROSSINGS ARE FOUR AND THEIR CALL SITES ARE SIX. Plan 029 says four, and
# it is counting crossings; `look` and `must_look` each dispatch on `$Typeof`
# into a `Slot*` arm and an `Inner*` arm, and each arm is a site of its own
# that can be dropped on its own. The measurement wins over the charter's
# figure and this is where it is written down (`3tk-rules-001.md` Rule 10).
#
# The count is the check and the negatives are the proof: `unstamped_insert`
# proves the guard aborts, `unstamped_crossing` proves the crossing does, and
# this proves the other four were not quietly dropped by a later stage.
#
# `check_stamped` is grepped and not `@check`, because the whole point of the
# shared macro is that all six carry the same null tolerance. A site that
# open-coded the condition would be a site that could get the tolerance wrong,
# and it must go red here.
echo "== Part 5.2: the identity check at both boundaries =="
CROSSINGS=$(grep -c 'inner::internal::check_stamped(' src/helper.c3)
if [ "$CROSSINGS" -eq 6 ]; then
    ok "the four crossings of src/helper.c3 check the identity, on all six arms"
else
    bad "src/helper.c3 has $CROSSINGS of the 6 identity checks Part 5.2 requires"
fi
for f in queue pool; do
    N=$(grep -c 'inner::internal::check_stamped(' "src/$f.c3")
    if [ "$N" -eq 1 ]; then
        ok "src/$f.c3's @guard_insert checks the identity"
    else
        bad "src/$f.c3 has $N of the 1 identity check Part 5.2 requires at its insertion"
    fi
done
# And the gate. `check_stamped` goes through `mtk::@check`, which is
# `$if env::COMPILER_SAFE_MODE`-gated, so a fast build carries nothing: the
# condition is not evaluated and `outer_tid` is never called. A body that
# reached for `always_assert` or a bare `assert` instead would put the check
# into every build, which is the one thing Part 5.2 forbids.
GUARD_BODY=$(awk '/^macro check_stamped\(/,/^}/' src/inner.c3)
if printf '%s\n' "$GUARD_BODY" | grep -q 'mtk::@check(' \
   && ! printf '%s\n' "$GUARD_BODY" | grep -qE '(^|[^:@])\b(assert|always_assert)\('; then
    ok "check_stamped is gated on the safe build and a fast build carries nothing"
else
    bad "check_stamped no longer goes through mtk::@check — the check is in every build"
fi
echo

echo "=========================================="
printf 'passed %s, failed %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "all four builds green"
