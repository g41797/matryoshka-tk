# Print Server — Analysis and Story Notes (001)

Companion to [print-server-001.md](print-server-001.md).

---

## Why this domain

The video transcoder (Story 1) demonstrated pool as backpressure signal and ownership routing. Both patterns were underused before that story.

After reading the existing 56 examples and the pattern catalog, two patterns had no story:

- Request-response: a result flowing back to the original sender through ownership transfer.
- OOB: an urgent signal that must arrive ahead of normal queue items.

The print server makes both patterns feel necessary, not optional. Every engineer knows what a print server does. The need for cancellation-before-next-job is immediately obvious. The need for a result to reach the submitter is obvious. Neither requires explaining.

---

## What Story 2 teaches

Story 1 teaches: the pool is not storage. It is a backpressure signal. An empty pool pauses the network ingest without any explicit coordination.

Story 2 teaches: ownership is not just resource management. It is synchronization. The job's location answers every status question without a shared table, without polling, without locks.

---

## Pattern coverage

| Story | Central insight | Matryoshka patterns |
| :---- | :-------------- | :------------------ |
| 1 — Video Transcoder | pool as backpressure signal; own state, not data | Pool + Io.Select event source + Io.Group + mailbox transport |
| 2 — Print Server | who owns the job answers all status questions; OOB for priority | Mailbox + OOB + two-Master coordination + per-client reply channel |

---

## Story registry placement

Three options.

1. Keep analysis per-story in `design/stories/` — e.g., this file. Easy to find alongside the story.

2. Create a story registry doc — `design/stories/registry-001.md` — that lists every story, its central insight, and its pattern coverage. Analysis from all stories feeds into it.

3. Append a "Story catalog" section to `matryoshka-storytelling-001.md`. The model doc already explains the philosophy; a catalog shows how stories accumulate.

Option 2 scales best. Each story produces a short registry entry. Writers consult the registry before choosing a new domain, to avoid covering the same insight twice.

---

## Future story candidates

| Domain | Central insight | Hero pattern |
| :----- | :-------------- | :----------- |
| Log collector | mailbox is needed when senders are independent and unknown — not a preference, a structural necessity | Fan-in; mailbox-less → mailbox transition (example 61 at story scale) |
| Build pipeline | stage count is a deployment choice, not an architecture choice | Independent Masters; Io.Group per stage; configurable parallelism |
| Sensor gateway | a unified event loop handles heterogeneous sources without case-specific threads | Io.Select + multiple source types (pool + mailbox + timer in one loop) |

Each candidate covers a pattern not yet central to any story.
