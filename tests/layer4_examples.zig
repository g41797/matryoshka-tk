const layer4 = @import("examples").layer4;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;

const allocator = std.testing.allocator;

test "95 - worker finish signal via mailbox return" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.mailbox_as_item.worker_finish_signal_via_mailbox_return(allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "96 - pool holds pools at teardown" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.pool_as_item.pool_holds_pools_at_teardown(allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "17 - minimal master" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.minimal_master.minimal_master(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "18 - master with pool" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.master_with_pool.master_with_pool(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "19 - multi-worker master" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.multi_worker_master.multi_worker_master(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "20 - pipeline of masters" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.pipeline_masters.pipeline_of_masters(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "21 - request-response between masters" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.request_response.request_response_between_masters(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "22 - timer via mailbox" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.timer_via_mailbox.timer_via_mailbox(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "23 - OOB signal via send_oob" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.oob_signal.oob_via_send_oob(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "24 - multiple event sources one mailbox" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.multi_source_mailbox.multiple_event_sources_one_mailbox(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "25 - table dispatch, two masters" {
    std.testing.log_level = .debug;
    var threaded: std.Io.Threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.table_dispatch_masters.table_dispatch_two_masters(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}
