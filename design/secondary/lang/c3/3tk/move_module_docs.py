"""3TK-47. The copy itself. Called by `move-module-docs.sh`.

    move_module_docs.py in|out <reference.md> <src dir> [module ...]

`in` replaces each module's `<* *>` with the reference's labelled block. `out`
replaces each labelled block with what the source holds. Nothing is composed,
nothing is reworded, and no declaration is read.
"""

import glob, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doc_blocks as db


def sources(src_dir):
    """The file that carries each module's description.

    3TK-63 made this a choice rather than a lookup. A module may be written in
    several files — `module mtk;` is `mtk.c3`, `inner.c3` and `queue.c3` — and
    it has ONE description however many sections it is written in. The carrier
    is the file that already holds a `<* *>` above its module line; the others
    are sections and carry a `//` banner saying so.

    Two carriers for one module is a defect and stops the move: writing to
    either would leave the other stale, and `check-doc-loop.sh` reports the same
    condition. With no carrier at all the first file wins, which is the old
    behaviour and the only sane insertion point.
    """
    seen = {}
    for p in sorted(glob.glob(os.path.join(src_dir, '*.c3'))):
        text = open(p).read()
        name = db.module_of(text)
        if not name:
            continue
        seen.setdefault(name, []).append((p, bool(db.source_block(text)[3])))
    out = {}
    for name, entries in seen.items():
        carriers = [p for p, has in entries if has]
        if len(carriers) > 1:
            raise SystemExit('%s is described in %d files: %s'
                             % (name, len(carriers),
                                ', '.join(os.path.basename(c) for c in carriers)))
        out[name] = carriers[0] if carriers else entries[0][0]
    return out


def move_in(ref_text, blocks, files, wanted):
    changed = 0
    for name in wanted:
        path = files[name]
        text = open(path).read()
        found = db.source_block(text)
        _, first, last, old = found
        new = db.to_source(blocks[name])
        if old == new:
            print('  %-14s %-12s unchanged' % (name, os.path.basename(path)))
            continue
        lines = text.splitlines()
        lines[first:last + 1] = ['<*'] + new + ['*>']
        open(path, 'w').write('\n'.join(lines) + '\n')
        what = 'inserted' if not old else 'replaced'
        print('  %-14s %-12s %s, %d lines' % (name, os.path.basename(path), what, len(new)))
        changed += 1
    return changed


def move_out(ref_path, ref_text, blocks, files, wanted):
    lines = ref_text.splitlines()
    # Rewritten back to front, so earlier spans keep their line numbers.
    spans = []
    for name in wanted:
        text = open(files[name]).read()
        _, first, last, src = db.source_block(text)
        spans.append((name, db.to_ref(src)))
    open_re = db.OPEN
    marks, cur, fence = {}, None, False
    for i, l in enumerate(lines):
        if l.startswith('```'):
            fence = not fence
            continue
        if fence:
            continue
        m = open_re.match(l)
        if m:
            cur = (m.group(1), i)
        elif l == db.CLOSE and cur:
            marks[cur[0]] = (cur[1], i)
            cur = None
    changed = 0
    for name, new in sorted(spans, key=lambda s: marks[s[0]][0], reverse=True):
        o, c = marks[name]
        if lines[o + 1:c] == new:
            print('  %-14s unchanged in the reference' % name)
            continue
        lines[o + 1:c] = new
        print('  %-14s rewritten in the reference, %d lines' % (name, len(new)))
        changed += 1
    if changed:
        open(ref_path, 'w').write('\n'.join(lines) + '\n')
    return changed


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    direction, ref_path, src_dir = sys.argv[1:4]
    wanted = sys.argv[4:]

    ref_text = open(ref_path).read()
    blocks = db.ref_blocks(ref_text)
    files = sources(src_dir)

    if not wanted:
        # `mtk` first: it is the one the owner's probe sits in.
        wanted = sorted(blocks, key=lambda n: (n != 'mtk', n))
    for name in wanted:
        if name not in blocks:
            print('no labelled block for %s' % name, file=sys.stderr)
            return 2
        if name not in files:
            print('no source file declares %s' % name, file=sys.stderr)
            return 2

    print('== move %s: %d module%s ==' % (direction, len(wanted), '' if len(wanted) == 1 else 's'))
    if direction == 'in':
        n = move_in(ref_text, blocks, files, wanted)
    else:
        n = move_out(ref_path, ref_text, blocks, files, wanted)
    print('  -- %d changed, %d already equal' % (n, len(wanted) - n))
    return 0


if __name__ == '__main__':
    sys.exit(main())
