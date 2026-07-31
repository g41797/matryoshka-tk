const layer1 = @import("examples").layer1;
const std = @import("std");

const allocator = std.testing.allocator;
const io = std.Io.Threaded.global_single_threaded.*.io();

test "21 - define a PolyNode type" {
    std.testing.log_level = .debug;
    layer1.define_type.define_a_polynode_type(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "22 - item transfer via Slot" {
    std.testing.log_level = .debug;
    layer1.ownership_transfer.item_transfer_via_slot(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "23 - tag-dispatch consume loop" {
    std.testing.log_level = .debug;
    layer1.tag_dispatch.tag_dispatch_consume_loop(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "24 - builder pattern" {
    std.testing.log_level = .debug;
    layer1.builder.builder_pattern(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "25 - produce-consume with defer cleanup" {
    std.testing.log_level = .debug;
    layer1.produce_consume.produce_consume_with_defer_cleanup(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "26 - tag-first dispatch loop" {
    std.testing.log_level = .debug;
    layer1.tag_first_dispatch.tag_first_dispatch_loop(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "27 - table dispatch loop" {
    std.testing.log_level = .debug;
    layer1.table_dispatch.table_dispatch_loop(allocator, io) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}
