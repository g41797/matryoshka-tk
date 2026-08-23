#!/usr/bin/env python3
"""Repair relative Markdown links after files have been moved. Reports by default.

The problem it solves. Reorganizing documentation — retiring superseded versions
into a `backup/`, lifting shared documents out of one consumer's folder into a
`common/` — breaks every relative link that names a moved file. Hand-editing
them is where the mistakes live, and the mistakes are asymmetric:

  * The links POINTING AT a moved file are the ones a human remembers. They are
    easy to grep for and easy to fix.
  * The links INSIDE the moved file, pointing back out at everything that did
    not move, are the ones a human forgets. They were correct before the move
    and are silently wrong after it, and nothing draws attention to them.

Both directions are the same operation, so this tool does not distinguish them.

How it works. It walks the tree once and builds a map from BASENAME to the file's
actual location. Then, for every `](...md)` link in every Markdown file, it
resolves the link's basename through that map and rewrites the relative path to
wherever the file now is. A link that is already correct is left untouched, so
the tool is idempotent: a clean second run is the verification that the first
one finished.

The basename is the identity. This is the design decision the tool rests on, and
it is also its one limitation: if two files anywhere in the tree share a
basename, the tool cannot tell which one a link means. It reports those as
AMBIGUOUS and leaves every link to them alone, rather than guessing. In a tree
where document names carry version suffixes — `foo-001.md`, `foo-002.md` — the
assumption holds; `README.md` is the usual exception, and it is usually fine to
leave those to a human.

What it does not do:

  * It does not touch links to anything but `.md`, and it skips URLs.
  * It does not touch bare filename MENTIONS, only real Markdown links. That is
    deliberate. Prose that names `foo-001.md` in backticks is very often
    PROVENANCE — a record of which document version a piece of work was written
    against — and provenance is not a pointer. Correcting where a file lives is
    allowed; repointing a record at a newer version is not, and a tool that
    rewrote every textual mention could not tell the two apart.
  * It does not create, delete or move anything. Move the files first, with `mv`,
    then run this.

Anything it cannot resolve — a link whose basename exists nowhere in the tree —
is reported at the end as a dangling link. That list should be empty.

Usage:
    relink_md.py [root]              # report what would change, edit nothing
    relink_md.py [root] --apply      # rewrite the files

`root` defaults to design/secondary/lang, the port-family tree this was written
for. Exits non-zero if any link dangles, so it can be used as a gate.
"""

import collections
import os
import re
import sys

LINK = re.compile(r"\]\(([^)\s]+\.md)(#[^)]*)?\)")

DEFAULT_ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "design", "secondary", "lang",
)


def locate(root):
    """basename -> every path in the tree carrying that basename."""
    found = collections.defaultdict(list)
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            if name.endswith(".md"):
                found[name].append(os.path.join(dirpath, name))
    return found


def main(argv):
    apply_edits = "--apply" in argv
    positional = [a for a in argv[1:] if not a.startswith("-")]
    root = os.path.abspath(positional[0]) if positional else DEFAULT_ROOT

    if not os.path.isdir(root):
        sys.stderr.write("not a directory: %s\n" % root)
        return 2

    found = locate(root)
    ambiguous = {k: v for k, v in found.items() if len(v) > 1}
    for name in sorted(ambiguous):
        print("AMBIGUOUS basename, every link to it left alone: %s -> %s"
              % (name, [p[len(root) + 1:] for p in ambiguous[name]]))

    changed_files = 0
    changed_links = 0
    dangling = []

    for dirpath, _, filenames in os.walk(root):
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as handle:
                before = handle.read()

            def repair(match, _dirpath=dirpath, _path=path):
                nonlocal changed_links
                target, fragment = match.group(1), match.group(2) or ""
                if "://" in target:
                    return match.group(0)
                base = os.path.basename(target)
                if base in ambiguous:
                    return match.group(0)
                if base not in found:
                    dangling.append((_path[len(root) + 1:], target))
                    return match.group(0)
                wanted = os.path.relpath(found[base][0], _dirpath)
                if wanted == target:
                    return match.group(0)
                changed_links += 1
                print("  %-56s %s -> %s" % (_path[len(root) + 1:], target, wanted))
                return "](%s%s)" % (wanted, fragment)

            after = LINK.sub(repair, before)
            if after != before:
                changed_files += 1
                if apply_edits:
                    with open(path, "w", encoding="utf-8") as handle:
                        handle.write(after)

    print()
    print("files %s: %d   links rewritten: %d"
          % ("rewritten" if apply_edits else "would change", changed_files, changed_links))

    if dangling:
        print("\nDANGLING — no file with that basename exists anywhere under the root:")
        for source, target in dangling:
            print("  %s -> %s" % (source, target))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
