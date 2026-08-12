#!/usr/bin/env bash
# Gate for the design/ folder. Four checks, all of which DOC 22 ran by hand:
#
#   1. Dead cross-references, in both syntaxes. DOC 22's manual sweep only
#      validated [text](target.md); refs written as `target.md` were invisible
#      to it and 23 of them were dead.
#   2. Orphans. Every file under design/ is named in exactly one context.md.
#   3. Forward-looking prose. design/ describes what is, not what will be.
#   4. Glossary conformance. Retired vocabulary must not reappear.
#
# Exit 0 when clean, 1 on any hit. Read-only — reports, never edits.
#
# design/secondary/ is exempt from checks 1, 3 and 4: it is frozen by the
# "Where a doc lives" rule in rules-043.md and its links are not repaired.
# STATUS-LOG.md is exempt from the same three: it is an append-only historical
# narrative and legitimately names docs that no longer exist.
set -uo pipefail

repo_root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
design="$repo_root/design"

hits=0

report() {
    hits=$((hits + 1))
    printf '%s\n' "$1"
}

# Files subject to the strict checks: design/*.md and design/stories/*.md,
# minus the historical narrative.
primary_docs() {
    find "$design" -maxdepth 2 -name '*.md' \
        -not -path "$design/secondary/*" \
        -not -name 'STATUS-LOG.md' \
        | sort
}

# Resolve a doc reference to a real file. Tries the referring file's own
# directory first, then the three folders a design doc may point into, then
# the repo root (for README.md and friends).
resolve() {
    local from_dir="$1" target="$2" c
    for c in "$from_dir/$target" "$design/$target" \
             "$design/secondary/$target" "$design/stories/$target" \
             "$repo_root/$target"; do
        [ -e "$c" ] && return 0
    done
    return 1
}

echo "== 1. dead cross-references =="

while IFS= read -r f; do
    rel="${f#$repo_root/}"
    dir="$(dirname "$f")"

    # A change-log or ledger row names the doc it replaced. That name is the
    # point of the row, so those lines are not scanned. Same reasoning as the
    # glossary exemptions below.
    grep -vE '^\| *[0-9]{3} *\||^- (DOC|INTR|CMPCT|DISPATCH) ' "$f" > /tmp/.cd_body.$$

    # Markdown links: [text](target). Skip anchors, URLs and mail links.
    grep -o '](\([^)]*\))' /tmp/.cd_body.$$ 2>/dev/null \
        | sed 's/^](//; s/)$//; s/#.*$//' \
        | grep -v '^$' \
        | grep -v '^[a-z][a-z0-9+.-]*://' \
        | sort -u \
        | while IFS= read -r t; do
            resolve "$dir" "$t" || echo "  DEAD link  $rel -> $t"
          done

    # Backtick refs: `target.md`. Same resolution, same failure.
    # NNN / 0NN are filename templates in rules-043.md, not references.
    grep -o '`[A-Za-z0-9._/-]\{3,\}\.md`' /tmp/.cd_body.$$ 2>/dev/null \
        | tr -d '`' \
        | grep -vE '(NNN|0NN)' \
        | sort -u \
        | while IFS= read -r t; do
            resolve "$dir" "$t" || echo "  DEAD ref   $rel -> $t"
          done
done < <(primary_docs) > /tmp/.cd_links.$$ 2>/dev/null
rm -f /tmp/.cd_body.$$

if [ -s /tmp/.cd_links.$$ ]; then
    cat /tmp/.cd_links.$$
    hits=$((hits + $(wc -l < /tmp/.cd_links.$$)))
else
    echo "  ok"
fi
rm -f /tmp/.cd_links.$$

echo
echo "== 2. orphans =="

orphans=0
while IFS= read -r f; do
    base="$(basename "$f")"
    case "$base" in context.md) continue ;; esac
    if ! grep -qF "$base" "$design/context.md" "$design/secondary/context.md" 2>/dev/null; then
        report "  ORPHAN     ${f#$repo_root/}"
        orphans=$((orphans + 1))
    fi
done < <(find "$design" -type f \( -name '*.md' -o -name '*.png' -o -name '*.zig' \) | sort)
[ "$orphans" -eq 0 ] && echo "  ok"

echo
echo "== 3. forward-looking prose =="

# \b guards matter: without them "TODO" matches "auTODOc".
fwd='will be rewritten|in later stages|happens later|to be written|not yet written|\bTODO\b|\bTBD\b|coming soon'
fw=0
while IFS= read -r line; do
    [ -n "$line" ] && { report "  FUTURE     ${line#$repo_root/}"; fw=$((fw + 1)); }
done < <(grep -rnE "$fwd" --include='*.md' "$design" \
    --exclude-dir=secondary --exclude='STATUS-LOG.md' --exclude='STATUS.md' \
    --exclude='matryoshka-tk-implementation-plan-*.md' 2>/dev/null)
[ "$fw" -eq 0 ] && echo "  ok"

echo
echo "== 4. glossary conformance =="

# MayItem  — the type is Slot. Zero occurrences in src/.
# Block N  — the four things are Layers.
# ownership — retired in favour of hold/transfer. "owner" meaning the human
#            who runs the project is allowed, so only the noun is checked.
#
# Four exemptions, all cases where the retired word is the subject rather than
# the voice of the sentence:
#   - "Status file ownership" — the name of a rule in rules-043.md.
#   - change-log and ledger rows — "| 020 | ... dropped ownership framing ..."
#     and "- DOC 18 — ... DONE" record that a pass happened. Rewriting them
#     would falsify history.
#   - "Change from" notes at the head of a versioned doc, same reason.
#   - `022-ownership_transfer.zig` — an example filename, owner's decision.
# rules-043.md and language-of-matryoshka.md carry the banned-word table
# itself and are exempt from the ownership check.
# Beyond those, kitchen/tools/.check_design_allow holds literal substrings for the
# handful of change-log rows that record a banned-word pass. See its header.
gl=0
exempt='Status file ownership|ownership_transfer\.zig|^[^:]*:[0-9]+:\| *[0-9]{3} *\||^[^:]*:[0-9]+:- (DOC|INTR|CMPCT|DISPATCH) |^[^:]*:[0-9]+:Change from'

allow="$repo_root/kitchen/tools/.check_design_allow"
filter() {
    sed "s|^$repo_root/||" | grep -vE "$exempt" | {
        if [ -f "$allow" ]; then
            grep -vFf <(grep -v '^#' "$allow" | grep -v '^$')
        else
            cat
        fi
    }
}

for pat in 'MayItem' 'Block [1-4]' 'ownership'; do
    # rules-0NN.md and the glossary define these words. They are the two docs
    # that must be able to name a banned word in order to ban it.
    ex=(--exclude='rules-0[0-9][0-9].md' --exclude='language-of-matryoshka.md')
    while IFS= read -r line; do
        [ -n "$line" ] && { report "  GLOSSARY   $line"; gl=$((gl + 1)); }
    done < <(grep -rn "$pat" --include='*.md' "$design" \
        --exclude-dir=secondary --exclude='STATUS-LOG.md' "${ex[@]}" 2>/dev/null | filter)
done
[ "$gl" -eq 0 ] && echo "  ok"

echo
if [ "$hits" -eq 0 ]; then
    echo "design/ clean"
    exit 0
fi
echo "design/ has $hits problem(s)"
exit 1
