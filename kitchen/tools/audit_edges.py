"""Inventory for a give-back audit. Reports, never edits.

Two independent scans, described in design/audit-recipe-002.md:

  1. Give-back edges. Every call where the toolkit may hand the item back to
     the caller — a refused `send`, a `close` returning its list, a `put` the
     pool declines. Each site is classified by whether anything in the
     enclosing function would release the item.

  2. Documented asserts. Every `Assert:` entry in the docs, checked against
     the asserts that actually exist in src/.

The classifier reads text, not syntax. It over-reports BARE by design: a multi-line
`catch { ... }` block that does free the item still lands there. That is the
intended failure direction — it sends a human to read the site. A clean table
is not proof of a clean codebase.
"""

import os
import re

# Mailbox and pool calls that can leave the caller holding the item.
SLOT_EDGES = ["send_oob", "send", "put_all", "put"]
LIST_EDGES = ["receive_batch", "close"]

SLOT_CALL = re.compile(
    r"(\w[\w.*\[\]]*)\.(" + "|".join(SLOT_EDGES) + r")\(&(\w+)\)"
)
DISCARDED_LIST = re.compile(r"_\s*=\s*[\w.*\[\]]+\.(" + "|".join(LIST_EDGES) + r")\(\)")
FN_START = re.compile(r"^\s*(pub )?fn \w+")
RELEASES = re.compile(r"free|destroy|\.put\(|put_all|release")
COMMENT = re.compile(r"^\s*//")
IS_DEFER = re.compile(r"^\s*(defer|errdefer)\b")


def _zig_files(root, dirs):
    for d in dirs:
        base = os.path.join(root, d)
        for dirpath, _, names in os.walk(base):
            for n in sorted(names):
                if n.endswith(".zig"):
                    yield os.path.relpath(os.path.join(dirpath, n), root)


def _enclosing_fn(fn_starts, line_no):
    earlier = [i for i in fn_starts if i <= line_no]
    return earlier[-1] if earlier else 0


def scan_edges(root, dirs):
    """Classify every give-back edge. Returns a list of result tuples."""
    rows = []
    for rel in _zig_files(root, dirs):
        lines = open(os.path.join(root, rel)).read().split("\n")
        fn_starts = [i for i, l in enumerate(lines) if FN_START.match(l)]

        for i, line in enumerate(lines):
            # Comments name these calls to ban them. Not call sites.
            if COMMENT.match(line):
                continue
            # `defer pl.put(&slot)` is the release, not a transfer that needs
            # one. The edge that matters is the acquisition it protects.
            if IS_DEFER.match(line):
                continue

            m = SLOT_CALL.search(line)
            if m:
                var = m.group(3)
                body = lines[_enclosing_fn(fn_starts, i):i]
                covered = [
                    b.strip() for b in body
                    if re.search(r"\b(defer|errdefer)\b", b)
                    and re.search(r"\b" + re.escape(var) + r"\b", b)
                ]
                tail = line.split("catch", 1)[1] if "catch" in line else ""
                if covered:
                    verdict = "COVERED"
                elif RELEASES.search(tail):
                    verdict = "CATCH-FREES"
                else:
                    verdict = "BARE"
                rows.append((verdict, rel, i + 1, m.group(2), var))

            if DISCARDED_LIST.search(line):
                rows.append(("DISCARDED", rel, i + 1,
                             DISCARDED_LIST.search(line).group(1), "-"))
    return rows


def scan_asserts(root, doc_dirs, src_dir):
    """Find documented asserts with no matching assert in src/."""
    src_text = ""
    for dirpath, _, names in os.walk(os.path.join(root, src_dir)):
        for n in sorted(names):
            if n.endswith(".zig"):
                src_text += open(os.path.join(dirpath, n)).read()

    # The expression inside std.debug.assert(...) in src/, flattened.
    def norm(text):
        # Docs write `slot.*` where src writes `slot.*.?`; the optional
        # unwrap is noise for this comparison.
        return re.sub(r"\s+", "", text).replace(".?", "")

    real = set()
    for m in re.finditer(r"std\.debug\.assert\(([^;]+)\);", src_text):
        real.add(norm(m.group(1)))

    missing = []
    for d in doc_dirs:
        for dirpath, _, names in os.walk(os.path.join(root, d)):
            for n in sorted(names):
                if not n.endswith(".md"):
                    continue
                path = os.path.join(dirpath, n)
                rel = os.path.relpath(path, root)
                lines = open(path).read().split("\n")
                in_block = False
                for i, line in enumerate(lines):
                    if re.match(r"\s*-\s*Assert:\s*$", line):
                        in_block = True
                        continue
                    if in_block:
                        entry = re.match(r"\s+-\s+`([^`]+)`\s*$", line)
                        if not entry:
                            in_block = False
                            continue
                        claim = norm(entry.group(1))
                        # A documented assert is satisfied if any real assert
                        # contains it — docs drop the `self.*.` prefixes.
                        if not any(claim in r or r in claim for r in real):
                            missing.append((rel, i + 1, entry.group(1)))
    return missing
