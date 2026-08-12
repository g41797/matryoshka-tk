#!/usr/bin/env bash
# Inventory for a give-back audit. Reports, never edits.
#
# Two scans, both of which MBOX 1 ran by hand:
#
#   1. Give-back edges. Every call where the toolkit may hand the item back —
#      a refused send, a close returning its list, a put the pool declines.
#      Each site is classified by whether the enclosing function would release
#      the item.
#   2. Documented asserts. Every "Assert:" entry in the docs, checked against
#      the asserts that exist in src/. MBOX 1 found 15 that never did.
#
# Exit 0 always, hits or not. This is NOT a gate. BARE means "read this site",
# not "this is a defect" — MBOX 1 saw 48 BARE of which 2 mattered. Wiring it
# into a gate would fail on every run and get ignored.
#
# The classifier reads text, not syntax, and over-reports BARE by design:
# a multi-line `catch { ... }` that frees still lands there. A clean table is
# not proof of a clean codebase. Method: design/audit-recipe-001.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from audit_edges import scan_edges, scan_asserts

root = '$REPO_ROOT'

print('== 1. give-back edges ==')
print()
rows = scan_edges(root, ['src', 'tests', 'examples', 'stories'])
order = {'DISCARDED': 0, 'BARE': 1, 'CATCH-FREES': 2, 'COVERED': 3}
for verdict, rel, line, call, var in sorted(rows, key=lambda r: (order[r[0]], r[1], r[2])):
    print(f'  {verdict:<12} {rel}:{line}  {call}  slot={var}')

print()
counts = {}
for r in rows:
    counts[r[0]] = counts.get(r[0], 0) + 1
for k in ['DISCARDED', 'BARE', 'CATCH-FREES', 'COVERED']:
    print(f'  {k:<12} {counts.get(k, 0)}')
print()
print('  DISCARDED — a returned list dropped with _ = . Always wrong.')
print('  BARE      — no release found. Read the site; the classifier is not an oracle.')
print()

print('== 2. documented asserts with no assert in src/ ==')
print()
missing = scan_asserts(root, ['kitchen/docs', 'design'], 'src')
if not missing:
    print('  ok')
else:
    for rel, line, claim in missing:
        print(f'  {rel}:{line}  {claim}')
print()
print(f'  {len(missing)} unmatched')
"
