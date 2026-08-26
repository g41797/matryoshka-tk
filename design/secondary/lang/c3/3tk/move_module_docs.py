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
    """Every source file by the module it declares."""
    out = {}
    for p in sorted(glob.glob(os.path.join(src_dir, '*.c3'))):
        name = db.module_of(open(p).read())
        if name:
            out[name] = p
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
