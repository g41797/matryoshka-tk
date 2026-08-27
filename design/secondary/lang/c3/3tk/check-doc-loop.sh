#!/usr/bin/env bash
#
# 3TK-39. The doc loop's checker. Facts only, no opinions.
#
# The invariant:
#
#     Every descriptor line in `3tk/src` appears in
#     `design/secondary/lang/c3/ref/3tk-reference-004.md`.
#
# One direction only. The reference is allowed to say more — Usual flow, the
# diagrams, the whole of Part 6. The source is a subset of it, never the
# reverse. The property that matters is that no comment says anything the
# reference does not.
#
# The procedure this script serves is
# `design/secondary/lang/c3/ref/3tk-doc-loop-003.md`. Read it before acting on
# anything printed here. This script reports. It rules on nothing, and it
# rewrites nothing.
#
# Usage:  ./check-doc-loop.sh [file.c3 ...]
#
# With no argument, every file in `src/`. A bare name is looked up in `src/`.
# Exit 0 when nothing is missing and the ban scan is empty, 1 otherwise,
# 2 on a usage or environment failure.

set -u

ROOT=$(cd "$(dirname "$0")" && pwd) || exit 2
REF=${REF:-$ROOT/../ref/3tk-reference-004.md}
RULES=${RULES:-$ROOT/../../../../rules-049.md}
PY=${PYTHON:-python3}

[ -f "$REF" ] || { echo "no reference at $REF" >&2; exit 2; }
command -v "$PY" >/dev/null 2>&1 || { echo "no $PY" >&2; exit 2; }

FILES=()
if [ $# -eq 0 ]; then
    for f in "$ROOT"/src/*.c3; do FILES+=("$f"); done
else
    for a in "$@"; do
        if   [ -f "$a" ];           then FILES+=("$a")
        elif [ -f "$ROOT/src/$a" ]; then FILES+=("$ROOT/src/$a")
        else echo "no such file: $a" >&2; exit 2
        fi
    done
fi

PYTHONPATH=$ROOT "$PY" - "$REF" "$ROOT/src" "$RULES" "${FILES[@]}" <<'PYEOF'
import difflib, glob, os, re, sys

ref_path, src_dir, rules_path = sys.argv[1], sys.argv[2], sys.argv[3]
files = sys.argv[4:]

REF_TEXT = open(ref_path).read()
REF = re.sub(r'\s+', ' ', REF_TEXT).lower()

# Every declared name in `src/`, for the variant rule below.
DECLS = set()
for p in glob.glob(os.path.join(src_dir, '*.c3')):
    DECLS.update(re.findall(r'\b(?:macro|fn)\b[^(\n]*?(\w+)\s*\(', open(p).read()))


def norm(s):
    """Collapse whitespace, lowercase, drop terminal punctuation."""
    return re.sub(r'\s+', ' ', s).strip().lower().rstrip('.')


def doc_lines(text):
    """The descriptor lines of every `<* *>` block, with their line numbers.

    Dropped: blank lines, contract lines (`@param`, `@require`, ...), and
    fenced code blocks. What is left is what the file claims.
    """
    out, inblk, fence = [], False, False
    for i, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if line.startswith('<*'):
            inblk, fence = True, False
            continue
        if line.startswith('*>'):
            inblk = False
            continue
        if not inblk:
            continue
        if line.startswith('```'):
            fence = not fence
            continue
        if fence or not line or line.startswith('@'):
            continue
        out.append((i, line))
    return out


def match(sentence):
    """How the reference carries this sentence, or None.

    Both sides are collapsed to single spaces first. The reference wraps a
    sentence across two source lines and a `<* *>` block never does, so a
    plain `grep -F` reports misses that are defects of the grep, not of the
    document — 3TK-37 hit that on three of 27 sentences.

    Three shapes the register asks for and the reference does not use are
    normalised, and the one that carried the match is printed with it:

      plain    the sentence is in the reference as it stands
      pronoun  the comment says "It looks."; the reference says
               "`from_slot` — looks." The subject is the declaration either way
      variant  the register's "Same as `x()`." A cross-reference is not a
               claim, so what is checked is that `x` is declared in `src/` and
               that the difference clause after the comma is in the reference
    """
    n = norm(sentence)
    if not n:
        return 'blank'
    if n in REF:
        return 'plain'
    if norm(re.sub(r'^(it|they|the same) ', '', n)) in REF:
        return 'pronoun'
    m = re.match(r'^same as `(\w+)\(\)`(?:, (.*))?$', n)
    if m and m.group(1) in DECLS:
        diff = m.group(2)
        if diff is None or norm(re.sub(r'^and (it )?', '', diff)) in REF:
            return 'variant'
    return None


# --- the module-block check ---
#
# The second kind of check, and the one 3TK-47 added. A module description is
# not judged and not matched sentence by sentence: it is a copy of the
# reference's labelled block, and the check is a `diff`. The transformation is
# one leading space per line and nothing else. `doc_blocks.py` holds it, and
# `ref/3tk-doc-loop-003.md` rules on it under *Moving a module description*.
#
# The two checks report separately and the exit status covers both.

import doc_blocks as db

print('== module blocks ==')
REF_BLOCKS = db.ref_blocks(REF_TEXT)
print('  %d labelled block%s in the reference' % (
    len(REF_BLOCKS), '' if len(REF_BLOCKS) == 1 else 's'))
differing = 0
for path in files:
    text = open(path).read()
    got = db.source_block(text)
    name = got[0] if got else None
    base = os.path.basename(path)
    if name is None:
        print('  %-12s declares no module' % base)
        continue
    if name not in REF_BLOCKS:
        print('  %-12s %-14s NO LABELLED BLOCK in the reference' % (base, name))
        differing += 1
        continue
    want = db.to_source(REF_BLOCKS[name])
    have = got[3]
    if have == want:
        print('  %-12s %-14s same, %d lines' % (base, name, len(have)))
    else:
        print('  %-12s %-14s DIFFERS' % (base, name))
        for d in difflib.unified_diff(want, have, 'reference', base, lineterm=''):
            print('    %s' % d)
        differing += 1
print('  -- %d differing block%s' % (differing, '' if differing == 1 else 's'))

# --- the descriptor check ---

total = found = missing = 0
for path in files:
    print('== %s ==' % os.path.basename(path))
    n = ok = bad = 0
    for lineno, line in doc_lines(open(path).read()):
        for sentence in re.split(r'(?<=\.) +', line):
            how = match(sentence)
            if how == 'blank':
                continue
            n += 1
            if how:
                ok += 1
                print('  %-4d found %-8s: %s' % (lineno, how, sentence))
            else:
                bad += 1
                print('  %-4d MISSING         : %s' % (lineno, sentence))
    print('  -- %d sentences, %d found, %d missing' % (n, ok, bad))
    total, found, missing = total + n, found + ok, missing + bad

print('== descriptors ==')
print('  %d sentences, %d found, %d missing' % (total, found, missing))

# --- the live banned-word scan ---
#
# Part 5 of `design/rules-049.md` is the source of truth and this is a scan,
# not a second copy of it. Read the Part before acting on a hit: `object` is
# banned only for an item or a `Handle`, `hold` only in the custody sense, and
# a hit is reported to the owner, never fixed on this script's authority.
#
# In a `.c3` file only the `<* *>` text is scanned. A mutex's `unlock()` is a
# stdlib name, and Part 5 says a stdlib name is not a hit.

BANNED = """
drain dll DLL seam seamless sweep settle settled underneath hatch lifecycle
ledger hands robust seamlessly comprehensive leverage efficient powerful
facilitate utilize ensure performant ergonomic idiomatic streamline orchestrate
sophisticated intuitive scalable unlock empower harness deliver fed arm leg
idempotent fires faces pitch paradigm mindset ownership gained wire wired wires
wiring object
""".split() + ['on purpose', 'object model', 'execution context',
               'execution model', 'programming model']
BAN_RE = re.compile(r'\b(%s)\b' % '|'.join(sorted(BANNED, key=len, reverse=True)))

print('== banned words ==')
if not os.path.exists(rules_path):
    print('  (rules-049.md not found at %s — the word list is a copy, and the'
          ' Part stays the source of truth)' % rules_path)
hits = 0
for path in files + [ref_path]:
    text = open(path).read()
    if path.endswith('.c3'):
        lines = doc_lines(text)
    else:
        lines = list(enumerate(text.splitlines(), 1))
    got = [(i, l) for i, l in lines if BAN_RE.search(l)]
    name = os.path.basename(path)
    if got:
        print('  %s:' % name)
        for i, l in got:
            print('    %-4d %s' % (i, l))
        hits += len(got)
    else:
        print('  %s: 0' % name)
print('  -- %d hits' % hits)

sys.exit(1 if (missing or hits or differing) else 0)
PYEOF
