# Docs Tooling — Content-Authoring Approach

Replaces [docs-tooling-approach-001.md](docs-tooling-approach-001.md) —  
wording-only change (dropped the banned word "pitch", see rules-022).

Companion to [matryoshka-tk-docs-plan-003.md](matryoshka-tk-docs-plan-003.md).  
Captures the working method established during DOC 5, so later DOC stages  
follow the same discipline without re-deriving it.

## Stack

- mkdocs (Material theme) generates the site from `kitchen/docs/*.md` plus
  Zig autodocs.
- `/home/g41797/dev/root/github.com/g41797/tofu` is the working prototype/
  reference for how mkdocs + generated-from-source docs are wired up in this  
  owner's other Zig projects.
- `kitchen/` is the sole housekeeping folder — tools, scripts, configs, and
  hand-authored narrative markdown — mirroring the same-named folder in the  
  Odin `matryoshka` repo's `kitchen/`.

## Content-authoring approach (established DOC 5, 2026-07-04)

Doc-site content stages are scoped narrowly and top-down, mirroring the  
"no skipping stages" rule already used for code stages (STATUS.md). Before  
writing any content stage:

- Audit every candidate source in parallel (one Explore agent per source
  pool — e.g. `design/*.md`, `kitchen/docs/*.md`, the Odin repo's  
  `kitchen/docs/`, and any ad-hoc dumps like a saved ChatGPT session) and get  
  a short structured report per source: what's current vs superseded, what's  
  real content vs process/internal, what needs trimming vs is nav-ready  
  as-is.
- Ad-hoc brainstorm dumps (long ChatGPT sessions etc.) are usually mostly
  duplicates of `design/` content already refined — triage for the few  
  genuinely new ideas (a structural proposal, a closing tagline) rather  
  than re-deriving from scratch.
- Scope the stage to one thing at a time: e.g. DOC 5 was just one top-level
  "what is this and why" entry-point page + a stub nav skeleton showing  
  where later sections will slot in — not full content for every section.  
  Detail pages are deferred to later DOC N stages, scoped only when reached.
- Never dump a whole dense `design/*.md` source file into one nav page —
  each site page must be short and topic-scoped; split dense sources into  
  multiple narrow pages later.
