# Examples Catalog


## Shared building blocks

Most examples reuse three small helper areas instead of repeating setup  
code:

- **[Items](items/items.md)** — fake item types (`Event`, `Sensor`,
  `ShutdownCommand`, `Timer`) for the examples to send and pool. Not  
  production code.

- **[Hooks](hooks/AlwaysCreateHooks.md)** — sample `Pool.Hooks`
  implementations ([AlwaysCreateHooks](hooks/AlwaysCreateHooks.md),  
  [CappedPoolHooks](hooks/CappedPoolHooks.md)) used by the pool examples.

- **[Helpers](helpers/helpers.md)** — generic test glue (`expect`,
  `clearList`), not part of the library API.

## How to...

Grouped by topic:

- **[PolyNode](polynode.md)** — define a type, transfer via Slot, dispatch
  by tag.

- **[Mailbox](mailbox.md)** — send/receive, OOB, batches, shutdown.
- **[Pool](pool.md)** — get/put, seeding, teardown, fan-in/fan-out.
- **[Io — Select, Group, Future](io.md)** — event loops, cancellation,
  awaiting futures directly.

## Flow

- **[Master compositions](flow.md)** — bigger, cross-layer examples: full
  Masters combining Mailbox + Pool + Select/Group.

