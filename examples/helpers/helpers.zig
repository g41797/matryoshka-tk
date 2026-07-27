//! Just some shared test glue, not production code.

/// testing.expect() replacement for code where testing functions are disabled
pub fn expect(comptime err: anyerror, ok: bool, comptime msg: []const u8) anyerror!void {
    if (!ok) {
        log.err("{s}", .{msg});
        return err;
    }
}

const log = std.log;
const std = @import("std");
