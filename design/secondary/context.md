# Secondary — frozen material

These files are not the current picture of Matryoshka.

They are snapshots, drafts, process notes and unstarted intentions. Each is  
kept because it still has a use. None of them is maintained.

## Rules for this folder

- A doc in `design/` may link down into `secondary/`.
- A doc in `secondary/` is frozen. It is not updated. Its own links are not
  repaired.
- Nothing here is a source of truth.
- If `secondary/` and `design/` disagree, `design/` is right.

The current picture starts at [../context.md](../context.md).

## Contents

One line per doc: the link, what it is, why it is kept.

- [matryoshka-cookbook-structure.md](matryoshka-cookbook-structure.md) — full cookbook structure, one recipe per concept. Unbuilt. A real plan someone may execute.
- [matryoshka-tk-docs-plan-015.md](matryoshka-tk-docs-plan-015.md) — documentation work plan, almost entirely a DOC-stage session log. The detail behind the STATUS-LOG narrative.
- [docs-tooling-approach-002.md](docs-tooling-approach-002.md) — content-authoring method for DOC stages: mkdocs, `kitchen/`, the tofu reference. Accurate, but process rather than design.
- [mtk-readme.md](mtk-readme.md) — alternate draft of the README intro, the "troika" phrasing. Input to the editorial prose pass in STATUS.md "Next".
- [llvm-pointer-switch-bug-001.md](llvm-pointer-switch-bug-001.md) — why `switch` over tags does not compile. Repro plus build matrix. A compiler-bug write-up, not Matryoshka design. Referenced from `../table-dispatch-001.md`.
- [llvm-pointer-switch-repro.zig](llvm-pointer-switch-repro.zig) — standalone repro for the above. Outside the build graph. Build commands in its header comment.
- [video-transcoder-notations-001.md](video-transcoder-notations-001.md) — first notation experiment for the transcoder story. Input to the diagram-notation scan in STATUS.md "Next".
- [video-transcoder-notations-002.md](video-transcoder-notations-002.md) — second notation experiment. The larger of the two.
- [odin-to-zig-backport-001.md](odin-to-zig-backport-001.md) — every Odin idiom in the prototype, with its Zig equivalent. Extracted from the retired 0.16 implementation guide. The direction that still matters is backporting `matryoshka-tk` to Odin. Its Zig column is the pre-implementation proposal, not the shipped API.
- [print-server-analysis-001.md](print-server-analysis-001.md) — why the print-server domain was chosen, which patterns had no story. Method for picking the next story. Referenced from `../stories/print-server-002.md`.
