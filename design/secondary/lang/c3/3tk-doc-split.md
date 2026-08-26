# The source files serve the AI, not the user

**From the owner, 2026-08-25. Not produced by any stage and not versioned by
this folder.** Written down as said, before the discussion that follows it.
It is input, not a ruling: nothing here is decided until the owner decides it.

## What is wrong

The C3 files under
`design/secondary/lang/c3/3tk/src` are **a mix of implementation and source of
truth for the AI.**

There is a lot of explanation of **why this decision was taken and why the other
was not**, and a lot of **references to internal documents**.

There is **very little user orientation** — what this is for, how to call it,
and so on.

**We cannot use it to build documentation.** From a human user's point of view
it reads as slop.

## The idea

**A dedicated file**, with:

- a **common section**, and
- **a section per source file**, in the order we need to discuss them.

**For every decision, a short accumulated description.** We should not have to
travel through ten documents to find it. That description should be **enough for
the AI**, and enough for the owner to remember by.

## Two things to think about

**Marks in the sources instead of links.** Whether the source files should carry
some kind of mark — not a link — so the connection back to the design is kept
**temporarily, until the 3tk project matures**.

**Replace the AI comment with a "for human" comment**, suitable for
documentation generation.

## Status

**Open.** The shape of the dedicated file, what a section holds, what a mark
looks like, and what happens to the existing comments are all still to be
discussed.
