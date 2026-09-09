"""3TK-47. The two sides of a module description, and the one transformation.

A module description exists twice: as a labelled block in
`design/secondary/lang/c3/ref/3tk-reference-004.md`, and as the `<* *>` block
directly above `module X;` in `3tk/src`. Moving one is a copy in either
direction. The whole transformation is one leading space per line, added going
into the source and stripped coming out. A blank line stays blank.

`design/secondary/lang/c3/ref/3tk-doc-loop-003.md` rules on this under *Moving
a module description*. This file implements it and rules on nothing.

Two readers use it: `check-doc-loop.sh`, which diffs, and
`move-module-docs.sh`, which copies.
"""

import re

OPEN = re.compile(r'^<!-- 3tk:module ([\w:]+) -->$')
CLOSE = '<!-- /3tk:module -->'


def ref_blocks(text):
    """Every labelled block in the reference, as {module: [line, ...]}.

    A label inside a fenced code block is the worked example, not a block, and
    it is skipped. The example says `mtk::NAME`.
    """
    out, name, buf, fence = {}, None, None, False
    for raw in text.splitlines():
        line = raw.rstrip('\n')
        if line.startswith('```'):
            fence = not fence
            if name is not None:
                buf.append(line)
            continue
        if fence:
            if name is not None:
                buf.append(line)
            continue
        m = OPEN.match(line)
        if m:
            if name is not None:
                raise ValueError('%s opens inside %s' % (m.group(1), name))
            name, buf = m.group(1), []
            continue
        if line == CLOSE:
            if name is None:
                raise ValueError('close with no open')
            if name in out:
                raise ValueError('%s labelled twice' % name)
            out[name], name, buf = buf, None, None
            continue
        if name is not None:
            buf.append(line)
    if name is not None:
        raise ValueError('%s is never closed' % name)
    return out


def to_source(lines):
    """The block as it is written in a `<* *>`: one leading space per line."""
    return [(' ' + l) if l else l for l in lines]


def to_ref(lines):
    """The block as it is written in the reference: one leading space off."""
    return [l[1:] if l.startswith(' ') else l for l in lines]


# 3TK-70 WIDENED THIS, twice over.
#
# One: a file is no longer one module. `pool.c3` carries three sections and
# three of the others carry two, because `c3c docgen` groups by module and by
# nothing else and a module page wants one subject. So the readers below work in
# SECTIONS, not files, and a file contributes as many blocks as it has module
# lines.
#
# Two: the generic module line is the same shape. `module mtk::helper <Outer>;`
# was invisible to the old pattern, which is why `mtk::helper`'s description was
# prose in the reference rather than a labelled block it could diff. A trailing
# `<...>` and a trailing `@attr` are both accepted and neither is part of the
# name.
MODULE_LINE = re.compile(r'^module ([\w:]+)(?: *<[^>]*>)?(?: *@\w+)?;')


def module_of(text):
    """The module a source file declares first, or None."""
    names = modules_of(text)
    return names[0] if names else None


def modules_of(text):
    """Every module a source file declares, in the order the sections sit."""
    return [m.group(1) for m in
            (MODULE_LINE.match(l) for l in text.splitlines()) if m]


def source_blocks(text):
    """Every section's `<* *>` block: [(name, first, last, lines), ...].

    `first` and `last` are 0-based indices into `text.splitlines()` covering
    `<*` through `*>`. Any `//` line between the block and the `module` line
    is stepped over, never touched. When a section has no block, `first` is the
    `module` line, `last` is `first - 1`, and `lines` is empty — an insertion
    point.
    """
    lines = text.splitlines()
    out = []
    for i, l in enumerate(lines):
        m = MODULE_LINE.match(l)
        if not m:
            continue
        name = m.group(1)
        j = i - 1
        while j >= 0 and lines[j].startswith('//'):
            j -= 1
        if j < 0 or lines[j].strip() != '*>':
            out.append((name, i, i - 1, []))
            continue
        end = j
        while j >= 0 and lines[j].strip() != '<*':
            j -= 1
        if j < 0:
            raise ValueError('a `*>` above `module %s;` with no `<*`' % name)
        out.append((name, j, end, lines[j + 1:end]))
    return out


def source_block(text):
    """The FIRST section's block, for a caller that wants one. See `source_blocks`."""
    blocks = source_blocks(text)
    return blocks[0] if blocks else None
