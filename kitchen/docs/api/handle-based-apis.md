# Handle-based API

Mailbox and Pool are not manipulated directly.  
All operations use handles.

The handle is always the first argument:

```zig
mailbox.destroy(mbh, allocator);
pool.get(ph, .available_or_new);
```
