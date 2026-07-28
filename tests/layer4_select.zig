const layer4 = @import("examples").layer4;
const std = @import("std");
const testing = std.testing;
const Io = std.Io;

test "25 - Select two mailboxes and timer" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_two_mailboxes.two_mailboxes_timer_in_select(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "26 - Select cancel closes both mailboxes" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_cancel_close.timer_cancel_close_walk_remaining(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "27 - Select cancel master decides per source" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_cancel_master_decides.cancel_reports_master_decides(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "28 - Select mixed sources mailbox pool timer" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_mixed_sources.multiple_event_source_types_in_one_select(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "29 - Select cancel recycles pool items" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_cancel_recycle.cancel_master_close_pool_put_all(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "30 - mailbox receive with timeout and retry" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.mailbox_timeout.timeout_on_mailbox(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "31 - Select graceful shutdown no item loss" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_graceful_shutdown.graceful_shutdown_with_in_flight_items(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "42 - Select single mailbox and timer re-spawn" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_mailbox_event.mailbox_receive_as_select_event_source(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "43 - Select direct push via putOneUncancelable" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_direct_push.select_direct_queue_push(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "44 - Select mailbox close propagates closed" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_mailbox_close.select_mailbox_close_propagation(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "45 - Select cancel propagates canceled through mailbox" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_mailbox_cancel.select_cancel_propagation(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "46 - Select pool availability as event source" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_pool_event.pool_get_wait_as_select_event_source(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "47 - Select job pool workers put back master re-spawns" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_job_pool.job_pool_pattern(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "48 - Select mailbox pool timer three sources" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.select_mailbox_pool_timer.mixed_mailbox_pool_event_sources_in_select(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "49 - receive_future awaited directly" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.receive_future_direct.receive_future_awaited_directly(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "50 - get_wait_future awaited directly" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.get_wait_future_direct.get_wait_future_awaited_directly(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "51 - receive_future with timeout returns timeout" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.receive_future_timeout.receive_future_with_timeout(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "52 - receive_future on single-threaded backend" {
    std.testing.log_level = .debug;
    const sio: Io = std.Io.Threaded.global_single_threaded.*.io();
    layer4.future_single_threaded.concurrencyunavailable_on_single_threaded(testing.allocator, sio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "53 - pool fan-in three workers one master" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.pool_fan_in.pool_fan_in_many_workers_return(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "54 - pool fan-out master seeds three workers" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.pool_fan_out.pool_fan_out_many_workers_acquire(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "55 - producer consumer pool recycle" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.producer_consumer_recycle.producer_consumer_with_recycling(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "56 - job pool circular flow" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.job_pool_circular.job_pool_circular_flow(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

test "62 - receive router one registration many events" {
    std.testing.log_level = .debug;
    var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const tio: Io = threaded.io();
    layer4.receive_router.receive_router_one_registration(testing.allocator, tio) catch |err| {
        std.log.err("example failed: {s}", .{@errorName(err)});
        return err;
    };
}

// test "STRESS - pool fan-in race repro (temporary)" {
//     std.testing.log_level = .warn;
//     var i: usize = 0;
//     while (i < 500) : (i += 1) {
//         var threaded: Io.Threaded = Io.Threaded.init(testing.allocator, .{});
//         defer threaded.deinit();
//         const tio: Io = threaded.io();
//         layer4.pool_fan_in.pool_fan_in_many_workers_return(testing.allocator, tio) catch |err| {
//             std.log.err("STRESS iteration {d} failed: {s}", .{ i, @errorName(err) });
//             return err;
//         };
//     }
// }
