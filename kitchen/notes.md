# Kitchen Notes

Running notes about `kitchen/` tooling and generated content — what's  
generated vs. hand-authored, what's safe to edit directly. Not a  
versioned design doc (no no-overwrite rule) — edit in place.

## Generated vs. hand-authored under kitchen/docs/

**Generated — rewritten on every `gen_examples_docs.sh` run, don't edit  
by hand, edits will be lost**:
- `kitchen/docs/examples/layer1/*.md`
- `kitchen/docs/examples/layer2/*.md`
- `kitchen/docs/examples/layer3/*.md`
- `kitchen/docs/examples/layer4/*.md`
- `kitchen/docs/examples/items/*.md`
- `kitchen/docs/examples/hooks/*.md`
- `kitchen/docs/examples/helpers/*.md`
- `kitchen/docs/examples/stories/**/*.md`
- `kitchen/docs/apidocs/` (Zig autodoc output, `zig build docs`)

**Hand-authored — safe to edit directly, script never touches these**:
- `kitchen/docs/examples/index.md` — catalog overview
- `kitchen/docs/examples/polynode.md` — How-to PolyNode group
- `kitchen/docs/examples/mailbox.md` — How-to Mailbox group
- `kitchen/docs/examples/pool.md` — How-to Pool group
- `kitchen/docs/examples/io.md` — How-to Io (Select/Group/Future) group
- `kitchen/docs/examples/flow.md` — Flow (Master compositions) group

Reminder (rules-021, "Examples-catalog nav sync"): adding/removing/renaming  
a file under `examples/`/`stories/` means updating both the relevant group  
page above and `kitchen/mkdocs.yml`'s Examples Catalog `nav:` block — the  
generation script only mirrors `.zig` files, it never touches either.

## kitchen/diagrams/ and kitchen/docs/assets/diagrams/

Graphviz `dot` diagrams for `kitchen/docs/the-shape.md`. Different rule from  
everything else on this page — **committed to git, not gitignored**:

- `kitchen/diagrams/src/*.dot` — hand-authored source, human/AI-readable.
- `kitchen/docs/assets/diagrams/*.svg` + `*.png` — rendered output, tracked
  alongside the source so hand-tweaks to a rendered image survive.

`kitchen/tools/gen_diagrams.sh` renders `.dot` → `.svg`/`.png`. Manual-run  
only — NOT connected to `build_site.sh`/`preview_site.sh`/CI, unlike every  
other generator on this page. Run it by hand after editing a `.dot` file,  
review the diff, commit deliberately.

## kitchen/tools/fix_md_lists.sh

Permanent script, part of the doc build/preview/CI sequence (runs after  
`gen_examples_docs.sh`, before `mkdocs build`/`serve`). Auto-fixes every  
`kitchen/docs/**/*.md` in place: inserts a blank line before any list that  
directly follows plain text with no blank line, since CommonMark/  
Python-Markdown otherwise treats the list as a lazy paragraph continuation  
and collapses every bullet into one run-on sentence (rules-018/022  
"mkdocs blank-line-before-list rule"). Skips fenced code blocks. Mechanical  
formatting only — no wording changes, safe to run repeatedly.

## Visual language for Matryoshka

- PolyNode → small tag attached to every object.
- Mailbox → communication port / transfer station.
- Pool → storage rack / warehouse of reusable items.

## mkdocs plugins


[MkDocs PDF Export](https://github.com/zhaoterryy/mkdocs-pdf-export-plugin)

