<*
 A dispatch table hands the same identity to different handlers.

 - Declare a table of identity-to-handler rows.
 - Build two tables that disagree about what an `Event` means.
 - Dispatch the same outer through both and confirm each ran its own handler.
*>
module shc::dispatch_table;
import mtk;
import mtk::managed;
import shc::outers;
import shc::helpers;

faultdef DISPATCH_TABLE_FAILED;

struct Counter { usz logged; usz counted; }

alias Handler = fn void(Counter*, Slot*);

struct Row   { typeid id; Handler handler; }
struct Table { Row[] rows; }

fn void? Table.dispatch(&self, Counter* c, Slot* s)
{
    if (s.is_empty()) return;
    typeid have = s.peek().link.type;
    foreach (row : self.rows)
    {
        if (row.id == have) { row.handler(c, s); return; }
    }
    return DISPATCH_TABLE_FAILED~;
}

fn void log_event(Counter* c, Slot* s)   { c.logged++; }
fn void count_event(Counter* c, Slot* s) { c.counted++; }

fn void? dispatch_same_identity_two_ways(Allocator a)
{
    Row[2] log_rows = { { Event::typeid, &log_event }, { Sensor::typeid, &log_event } };
    Row[1] count_rows = { { Event::typeid, &count_event } };

    Table log_table = { .rows = log_rows[..] };
    Table count_table = { .rows = count_rows[..] };

    Slot s;
    defer mtk::managed::release(Event, &s);
    mtk::managed::create(Event, a, &s)!;

    Counter c;
    log_table.dispatch(&c, &s)!;
    shc::helpers::expect(DISPATCH_TABLE_FAILED, c.logged == 1, "the log table must run log_event on an Event")!;
    shc::helpers::expect(DISPATCH_TABLE_FAILED, s.is_full(), "a handler that does not take the outer leaves the Slot full")!;

    count_table.dispatch(&c, &s)!;
    shc::helpers::expect(DISPATCH_TABLE_FAILED, c.counted == 1, "the count table must run count_event on the same Event")!;
}
