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


def module_of(text):
    """The module a source file declares, or None."""
    for line in text.splitlines():
        m = re.match(r'^module ([\w:]+);', line)
        if m:
            return m.group(1)
    return None


def source_block(text):
    """The module's `<* *>` block: (name, first, last, lines).

    `first` and `last` are 0-based indices into `text.splitlines()` covering
    `<*` through `*>`. The `// [3tk: ...]` marks sit between the block and the
    `module` line and are stepped over, never touched. When the file has no
    module block, `first` is the `module` line, `last` is `first - 1`, and
    `lines` is empty — an insertion point.
    """
    lines = text.splitlines()
    i = next((k for k, l in enumerate(lines) if re.match(r'^module ([\w:]+);', l)), None)
    if i is None:
        return None
    name = re.match(r'^module ([\w:]+);', lines[i]).group(1)
    j = i - 1
    while j >= 0 and lines[j].startswith('//'):
        j -= 1
    if j < 0 or lines[j].strip() != '*>':
        return (name, i, i - 1, [])
    end = j
    while j >= 0 and lines[j].strip() != '<*':
        j -= 1
    if j < 0:
        raise ValueError('a `*>` above `module %s;` with no `<*`' % name)
    return (name, j, end, lines[j + 1:end])
