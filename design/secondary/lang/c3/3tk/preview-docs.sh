#!/usr/bin/env bash
#
# 3TK-38. Look at the doc comments the way a reader will.
#
# A `<* *>` block cannot be judged from its source. The renderer is
# `formatDocText` inside the generated `docs.html`; it is not CommonMark, and
# 3TK-31 was corrected once already by running it rather than reading it.
#
# Usage:  ./preview-docs.sh [--no-open]
#
# The page is generated into a fresh temporary directory and opened from there.
# `c3c docgen` writes `docs.html` into the CURRENT directory, so generating
# anywhere else is what keeps `3tk/` clean — 3TK-37 generated one into `3tk/`
# and had to delete it by hand. Nothing is added to `.gitignore`, because
# nothing is ever written here.

set -u

ROOT=$(cd "$(dirname "$0")" && pwd) || exit 2
C3C=${C3C:-c3c}
OPEN=1
[ "${1:-}" = "--no-open" ] && OPEN=0

OUT=$(mktemp -d) || exit 2
PAGE="$OUT/docs.html"

echo "== docgen =="
# --emit-stdlib=no: the toolkit only. The stdlib pages bury it otherwise.
# Warnings go to the terminal; they are the compiler's, not this script's.
( cd "$OUT" && $C3C docgen --emit-stdlib=no "$ROOT/src" ) || {
    echo "docgen failed" >&2; exit 1; }
[ -s "$PAGE" ] || { echo "no docs.html was produced" >&2; exit 1; }

# --- is the page self-contained? ---
#
# Reported, never assumed. Two different things can send the browser off the
# machine, and only one of them is fixed by serving the folder:
#
#   1. A same-origin fetch. `docs.html` falls back to `fetch('docs.json')` when
#      `EMBEDDED_JSON_LIST` is empty, and that fetch fails under `file://`.
#      THIS is what a local server exists for.
#   2. An absolute URL to another host. A server does not help — a remote host
#      is remote under either scheme. It costs a broken image, nothing more.
echo
echo "== self-containedness =="

EMBEDDED=$(grep -c 'EMBEDDED_JSON_LIST.push' "$PAGE")
EXTERNAL=$(grep -oiE '(src|href)="https?://[a-z0-9./-]+' "$PAGE" | sed 's/^[a-z]*="//' | sort -u)

if [ "$EMBEDDED" -gt 0 ]; then
    echo "  ok    the documentation data is embedded ($EMBEDDED target(s)) — no fetch is made"
    NEEDS_SERVER=0
else
    echo "  note  no embedded data: the page falls back to fetch('docs.json'), which file:// refuses"
    NEEDS_SERVER=1
fi

if grep -q 'window.marked ?' "$PAGE"; then
    echo "  ok    'marked' is named but guarded — it is never loaded, the page escapes instead"
fi

if [ -n "$EXTERNAL" ]; then
    echo "  note  absolute URLs, which no local server can bring closer:"
    printf '          %s\n' $EXTERNAL
else
    echo "  ok    no absolute URLs"
fi

echo
if [ "$NEEDS_SERVER" = "1" ]; then
    # ztk's shape: kitchen/tools/preview_apidocs.sh serves its folder.
    echo "Serving $OUT on http://localhost:8000  (Ctrl+C to stop)"
    [ "$OPEN" = "1" ] && ( xdg-open "http://localhost:8000/docs.html" >/dev/null 2>&1 & )
    ( cd "$OUT" && python3 -m http.server 8000 )
else
    echo "Page: $PAGE"
    if [ "$OPEN" = "1" ]; then
        xdg-open "$PAGE" >/dev/null 2>&1 &
        echo "Opened. The directory is temporary — nothing was written into 3tk/."
    fi
fi
