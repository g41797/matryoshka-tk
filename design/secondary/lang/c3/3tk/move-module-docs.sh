#!/usr/bin/env bash
#
# 3TK-47. The module-description move, in both directions.
#
# A module description is copied, never composed. The reference's labelled
# block and the `<* *>` block above `module X;` hold the same text, and the
# whole transformation is one leading space per line.
#
#     ./move-module-docs.sh in  [module ...]   reference -> src
#     ./move-module-docs.sh out [module ...]   src -> reference
#     ./move-module-docs.sh roundtrip          in, then out, on copies
#
# With no module named, all eight. `in` writes `src/*.c3` in place. `out`
# writes the reference in place. `roundtrip` writes neither: it copies both
# sides to a temporary tree, moves in and back out, and compares bytes.
#
# The `// [3tk: ...]` mark below a block is never touched. Declarations are
# never touched. The procedure is
# `design/secondary/lang/c3/ref/3tk-doc-loop-003.md`, *Moving a module
# description*.

set -u

ROOT=$(cd "$(dirname "$0")" && pwd) || exit 2
REF=${REF:-$ROOT/../ref/3tk-reference-004.md}
PY=${PYTHON:-python3}

[ $# -ge 1 ] || { sed -n '4,20p' "$0"; exit 2; }
[ -f "$REF" ] || { echo "no reference at $REF" >&2; exit 2; }
command -v "$PY" >/dev/null 2>&1 || { echo "no $PY" >&2; exit 2; }

DIR=$1; shift

case "$DIR" in
  in|out) "$PY" "$ROOT/move_module_docs.py" "$DIR" "$REF" "$ROOT/src" "$@" ;;
  roundtrip)
      TMP=$(mktemp -d) || exit 2
      trap 'rm -rf "$TMP"' EXIT
      mkdir -p "$TMP/src" || exit 2
      cp "$ROOT"/src/*.c3 "$TMP/src/" || exit 2
      cp "$REF" "$TMP/ref.md" || exit 2
      echo "== roundtrip: in, then out, on a copy =="
      "$PY" "$ROOT/move_module_docs.py" in  "$TMP/ref.md" "$TMP/src" "$@" || exit 1
      "$PY" "$ROOT/move_module_docs.py" out "$TMP/ref.md" "$TMP/src" "$@" || exit 1
      if diff -u "$REF" "$TMP/ref.md"; then
          echo "  reference byte-identical after the round trip"
      else
          echo "  ROUND TRIP CHANGED THE REFERENCE — the format is not byte-exact"
          exit 1
      fi
      ;;
  *) echo "unknown direction: $DIR" >&2; exit 2 ;;
esac
