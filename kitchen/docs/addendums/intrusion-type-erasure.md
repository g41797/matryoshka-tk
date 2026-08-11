## Intrusion and Type erasure

---

<a href="https://ziglang.org/documentation/0.16.0/std/#std.DoublyLinkedList" target="_blank" rel="noopener noreferrer">std.DoublyLinkedList</a> works with <a href="https://ziglang.org/documentation/0.16.0/std/#std.DoublyLinkedList.Node" target="_blank" rel="noopener noreferrer">Nodes</a>.

Just

- embed Node to you structs
- use DoublyLinkedList functions

DoublyLinkedList does not care

- what's the type of parent struct
- whether structs in the list have the same type

Because Node already has pointers , DoublyLinkedList

- does not need allocate wrappers for structs
- uses existing pointers(links)

Terms:

- **Intrusion** — the links are part of the struct
- **Type erasure** —  DoublyLinkedList operates on Node, not on the concrete type

---


Caller

- follows its own rules
- can get pointer to the parent struct
- via <a href="https://ziglang.org/documentation/0.16.0/#toc-fieldParentPtr"  target="_blank" rel="noopener noreferrer">@fieldParentPtr</a>

---


This simple mechanism is the basis of Matryoshka.


---
