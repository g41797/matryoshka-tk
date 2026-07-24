# Handle-based API

Mailbox and Pool use a _handle-based API_.

The handle is always the first argument:

```zig
mailbox.destroy(mbh, allocator);
pool.get(ph, .available_or_new);
```
