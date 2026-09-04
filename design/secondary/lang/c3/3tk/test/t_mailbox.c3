<*
 Part 11.3 to 11.6, Part 19.1 — the mailbox.

 Part 18 invariants 21, 22, 23, 26.
*>
module mtk_test;
import mtk;
import mtk::mailbox;
import std::thread;
import std::time;
import std::core::mem::alloc;
import std::atomic::types;

fn Mailbox* new_mailbox()
{
    return mailbox::create(mem)!!;
}

<*
 Close the mailbox and release it, giving back whatever was left.

 Part 11.6's named mistake is NOT to do this: discarding the list a close
 returns drops the outers, and those outers keep their links, so a later send
 refuses them.
*>
fn void drop_mailbox(Mailbox* mb)
{
    InnerQueue left;
    mb.close(&left);
    while (Inner* inner = left.pop_front()) { /* the caller's work, Part 11.6 */ }
    mb.release();
}

<*
 Part 11.1 MUST, invariant 21: the mailbox is itself an outer.

 It embeds an inner, it carries an identity, it crosses the border like any
 other outer, and it can sit on a list. This is the toolkit's stated reason for
 existing, and D1 is what keeps it literal.
*>
fn void a_mailbox_is_an_item() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Inner* inner = mailbox::to_inner(mb);
    always_assert(inner != null, "the mailbox has no inner");
    always_assert(inner.link.type == mailbox::TYPE, "the mailbox carries no identity");
    always_assert(mailbox::of(inner) == mb, "the mailbox did not survive the round trip");

    // and it sits on a list, beside an outer of another type
    Msg m;
    mtk::helper::init(&m);
    InnerQueue list;
    list.push_back(inner);
    list.push_back(mtk::helper::to_inner(&m));
    always_assert(list.len() == 2, "a mailbox would not go on a list");
    always_assert(mailbox::of(list.pop_front()) == mb, "the mailbox came off wrong");
    list.pop_front();
}

<*
 Send and receive, and Part 9.3's signature shape on both sides.
*>
fn void send_then_poll() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Msg m;
    mtk::helper::init(&m);
    m.id = 5;

    Slot s;
    s.fill(mtk::helper::to_inner(&m));
    if (catch mb.send(&s)) { always_assert(false, "send failed on an open mailbox"); }
    always_assert(s.is_empty(), "send did not clear the Slot");

    Slot r;
    if (catch mb.poll(&r)) { always_assert(false, "poll found nothing"); }
    always_assert(mtk::helper::move_from_slot(&r, Msg) == &m, "the wrong outer came back");
    always_assert(r.is_empty(), "the claim did not clear the Slot");
}

<*
 Part 19.1: poll reports EMPTY, and it never waits.
*>
fn void poll_on_an_empty_mailbox() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Slot r;
    if (catch f = mb.poll(&r))
    {
        always_assert(f == mtk::EMPTY, "an empty mailbox reported something other than EMPTY");
        always_assert(r.is_empty(), "a failed poll filled the Slot");
        return;
    }
    always_assert(false, "poll on an empty mailbox succeeded");
}

<*
 Part 11.3: ordinary outers are first-in first-out among themselves.
*>
fn void ordinary_items_are_fifo() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Msg[6] ms;
    for (usz i = 0; i < 6; i++)
    {
        ms[i].id = (int)i;
        mtk::helper::init(&ms[i]);
        Slot s;
        s.fill(mtk::helper::to_inner(&ms[i]));
        if (catch mb.send(&s)) { always_assert(false, "send failed"); }
    }

    for (usz i = 0; i < 6; i++)
    {
        Slot r;
        if (catch mb.poll(&r)) { always_assert(false, "poll failed"); }
        always_assert(mtk::helper::move_from_slot(&r, Msg).id == (int)i, "the mailbox is not first-in first-out");
    }
}

<*
 Part 11.3 MUST, invariant 22, and the clause with three halves:

   - out-of-band outers are first-in first-out among THEMSELVES,
   - every out-of-band outer sits ahead of every ordinary one,
   - and the anchor keeps the insert O(1).

 The interleaving here is deliberate: ordinary, oob, ordinary, oob, ordinary.
 A port that puts each out-of-band outer at the front gets the first clause
 backwards and this test catches it.
*>
fn void out_of_band_ordering() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Msg[6] ms;
    for (usz i = 0; i < 6; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); }

    // ordinary 0, oob 1, ordinary 2, oob 3, ordinary 4
    send_one(mb, &ms[0], false);
    send_one(mb, &ms[1], true);
    send_one(mb, &ms[2], false);
    send_one(mb, &ms[3], true);
    send_one(mb, &ms[4], false);

    // expected: 1, 3 (oob, in order), then 0, 2, 4 (ordinary, in order)
    int[5] want = { 1, 3, 0, 2, 4 };
    for (usz i = 0; i < 5; i++)
    {
        Slot r;
        if (catch mb.poll(&r)) { always_assert(false, "poll failed"); }
        always_assert(mtk::helper::move_from_slot(&r, Msg).id == want[i], "out-of-band ordering is wrong");
    }
}

fn void send_one(Mailbox* mb, Msg* m, bool oob)
{
    Slot s;
    s.fill(mtk::helper::to_inner(m));
    if (oob)
    {
        if (catch mb.send_oob(&s)) { always_assert(false, "send_oob failed"); }
    }
    else
    {
        if (catch mb.send(&s)) { always_assert(false, "send failed"); }
    }
    always_assert(s.is_empty(), "the send did not clear the Slot");
}

<*
 Part 11.3: the anchor is cleared when the last out-of-band outer is taken.

 Drain the out-of-band run, then send another one. It must go to the front
 again — if the anchor were left dangling, the new outer would be inserted after
 an outer that is no longer in the queue.
*>
fn void the_anchor_is_cleared() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Msg[4] ms;
    for (usz i = 0; i < 4; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); }

    send_one(mb, &ms[0], true);      // oob
    send_one(mb, &ms[1], false);     // ordinary

    Slot r;
    if (catch mb.poll(&r)) { always_assert(false, "poll failed"); }
    always_assert(mtk::helper::move_from_slot(&r, Msg).id == 0, "the out-of-band outer did not come first");

    // the out-of-band run is drained; the anchor must be gone
    send_one(mb, &ms[2], true);
    if (catch mb.poll(&r)) { always_assert(false, "poll failed"); }
    always_assert(mtk::helper::move_from_slot(&r, Msg).id == 2, "the new out-of-band outer did not go to the front");
}

<*
 Part 11.6: a batch receive gives the whole list to the caller.
*>
fn void receive_the_batch() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Msg[4] ms;
    for (usz i = 0; i < 4; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); send_one(mb, &ms[i], false); }

    InnerQueue got;
    if (catch mb.receive_all(&got)) { always_assert(false, "receive_all failed"); }

    always_assert(got.len() == 4, "the batch is the wrong size");
    always_assert(mb.len() == 0, "the mailbox kept something");
    for (usz i = 0; i < 4; i++)
    {
        always_assert(mtk::helper::from_inner(got.pop_front(), Msg).id == (int)i, "the batch is out of order");
    }
}

<*
 Part 11.6 MUST, invariant 23: every outer the mailbox keeps goes back to a
 caller — and close is the path that is easiest to get wrong.

 The outers come back with their links cleared, so they can be sent again. That
 is the second half of the named mistake: a dropped outer keeps its links and a
 later send refuses it.
*>
fn void close_gives_the_remainder_back() @test
{
    Mailbox* mb = mailbox::create(mem)!!;

    Msg[3] ms;
    for (usz i = 0; i < 3; i++) { ms[i].id = (int)i; mtk::helper::init(&ms[i]); send_one(mb, &ms[i], false); }

    InnerQueue left;
    mb.close(&left);
    always_assert(left.len() == 3, "close did not give the remainder back");

    for (usz i = 0; i < 3; i++)
    {
        Inner* inner = left.pop_front();
        always_assert(mtk::helper::from_inner(inner, Msg).id == (int)i, "the remainder is out of order");
        always_assert(!mtk::inner::is_linked(inner), "a returned outer kept its links");
    }
    mb.release();
}

<*
 Part 19.1: every operation on a closed mailbox reports CLOSED, and a refused
 send leaves the Slot unchanged — the sender still has the outer.

 Part 11.12: closedness is a precondition at release and NOWHERE else. Every
 other call reports closed and the object stays a valid outer.
*>
fn void a_closed_mailbox_refuses_everything() @test
{
    Mailbox* mb = mailbox::create(mem)!!;
    InnerQueue left;
    mb.close(&left);
    always_assert(left.is_empty(), "an empty mailbox returned a remainder");

    Msg m;
    mtk::helper::init(&m);
    Slot s;
    s.fill(mtk::helper::to_inner(&m));

    always_assert(@catch_is(mb.send(&s), mtk::CLOSED), "a closed mailbox accepted a send");
    always_assert(s.is_full(), "a refused send did not leave the Slot alone");
    always_assert(s.peek() == mtk::helper::to_inner(&m), "a refused send changed the Slot");

    always_assert(@catch_is(mb.send_oob(&s), mtk::CLOSED), "a closed mailbox accepted an out-of-band send");
    always_assert(s.is_full(), "a refused send_oob did not leave the Slot alone");

    Slot r;
    always_assert(@catch_is(mb.poll(&r), mtk::CLOSED), "a closed mailbox was polled");
    always_assert(@catch_is(mb.receive(&r, time::ms(1)), mtk::CLOSED), "a closed mailbox was received from");
    always_assert(@catch_is(mb.wake_all(), mtk::CLOSED), "a closed mailbox woke waiters");
    always_assert(r.is_empty(), "a refused receive filled the Slot");

    InnerQueue batch;
    always_assert(@catch_is(mb.receive_all(&batch), mtk::CLOSED), "a closed mailbox gave a batch");

    // and the mailbox is still a valid outer
    always_assert(mailbox::of(mailbox::to_inner(mb)) == mb, "a closed mailbox stopped being an outer");

    s.take();
    mb.release();
}

<*
 Part 11.12: close is callable more than once, and the second call takes
 nothing.
*>
fn void close_is_idempotent() @test
{
    Mailbox* mb = mailbox::create(mem)!!;

    Msg m;
    mtk::helper::init(&m);
    send_one(mb, &m, false);

    InnerQueue first;
    mb.close(&first);
    always_assert(first.len() == 1, "the first close did not give the outer back");

    InnerQueue second;
    mb.close(&second);
    always_assert(second.is_empty(), "the second close produced outers from nowhere");

    first.pop_front();
    mb.release();
}

<*
 Part 19.1: receive reports TIMEOUT on an empty mailbox, and the Slot is
 untouched.
*>
fn void receive_times_out() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Slot r;
    Clock c = clock::now();
    always_assert(@catch_is(mb.receive(&r, time::ms(60)), mtk::TIMEOUT), "receive did not time out");
    always_assert(r.is_empty(), "a timed-out receive filled the Slot");
    always_assert(c.mark().to_ms() >= 50, "receive returned before its deadline");
}

<*
 A deadline already in the past returns immediately.
*>
fn void a_past_deadline_returns_at_once() @test
{
    Mailbox* mb = new_mailbox();
    defer drop_mailbox(mb);

    Slot r;
    Clock c = clock::now();
    always_assert(@catch_is(mb.receive(&r, time::DURATION_ZERO), mtk::TIMEOUT), "a zero timeout did not time out");
    always_assert(c.mark().to_ms() < 100, "a zero timeout waited");
}

<*
 True when the call returned exactly this fault.
*>
macro bool @catch_is(#call, want)
{
    if (catch f = #call) return f == want;
    return false;
}

<*
 **Invariant 34, mailbox side. Part 11.6:** a closed mailbox is empty.

 The close takes the whole queue in one step under the mutex, and a send is
 refused after the flag is set under that same mutex, so there is no state in
 which the mailbox is closed and still holds something.

 That is what makes Part 19.1's outcome set a set rather than an ordering. A
 receive on a closed mailbox never has to choose between handing back an outer
 and reporting CLOSED, because there is never an outer left to hand back.

 `a_closed_mailbox_refuses_everything` closes an EMPTY mailbox, which cannot
 tell the two readings apart. This one closes a mailbox holding three.
*>
fn void a_closed_mailbox_is_empty() @test
{
    Mailbox* mb = new_mailbox();

    Msg[3] m;
    for (usz i = 0; i < 3; i++)
    {
        mtk::helper::init(&m[i]);
        m[i].id = (int)i;
        Slot s;
        s.fill(mtk::helper::to_inner(&m[i]));
        if (catch mb.send(&s)) { always_assert(false, "an open mailbox refused a send"); }
    }
    always_assert(mb.len() == 3, "the mailbox did not take three");

    InnerQueue left;
    mb.close(&left);

    // invariant 34: the close is the only drain, and it drained everything
    always_assert(left.len() == 3, "the close did not hand back all three");
    always_assert(mb.len() == 0, "a closed mailbox still holds outers");

    // so every acquisition reports CLOSED, and none of them can find an outer
    Slot r;
    always_assert(@catch_is(mb.poll(&r), mtk::CLOSED), "a closed mailbox answered a poll with an outer");
    always_assert(@catch_is(mb.receive(&r, time::ms(1)), mtk::CLOSED), "a closed mailbox answered a receive with an outer");
    always_assert(r.is_empty(), "a refused acquisition filled the Slot");

    InnerQueue batch;
    always_assert(@catch_is(mb.receive_all(&batch), mtk::CLOSED), "a closed mailbox answered a batch receive with outers");
    always_assert(batch.is_empty(), "a refused batch receive moved outers");

    while (Inner* inner = left.pop_front()) { /* the caller's work, Part 11.6 */ }
    mb.release();
}

struct Lifetime
{
    Mailbox*    mb;
    Atomic{usz} waiting;
    Atomic{usz} returned;
}

fn int parked_receiver(void* arg)
{
    Lifetime* lf = (Lifetime*)arg;
    Slot got;
    lf.waiting.store(1, RELEASE);
    bool closed = @catch_is(lf.mb.receive(&got, time::sec(30)), mtk::CLOSED);
    always_assert(closed, "the close did not wake the parked receiver with CLOSED");
    always_assert(got.is_empty(), "a refused receive filled the Slot");
    lf.returned.store(1, RELEASE);
    return 0;
}

<*
 **Part 11.12 — CLOSED, then QUIET, then FREED, with an assertion at each step.**

 The positive counterpart of `negative/release_while_receiving.c3`. That program
 proves the port stops when the rule is broken; this one proves what the caller
 is supposed to do instead, and runs it rather than reasoning about it.

 A worker parks in `receive`. The close publishes CLOSED and wakes it. The
 worker reports `CLOSED` and finishes. Only then is the mailbox quiet, and only
 then may it be released.

 `is_quiet()` reads the closed-and-active predicate itself, under the mutex —
 the public way to ask whether a tool is quiet, added by 3TK-58 for exactly
 this.
*>
fn void closed_then_quiet_then_freed() @test
{
    Mailbox* mb = new_mailbox();

    Lifetime lf;
    lf.mb = mb;

    Thread worker;
    worker.create(&parked_receiver, &lf)!!;

    while (lf.waiting.load(ACQUIRE) == 0) thread::sleep(time::ms(1))!!;
    thread::sleep(time::ms(50))!!;             // it is inside wait_until by now

    // CLOSED. The receiver is woken, and it has NOT returned yet.
    InnerQueue left;
    mb.close(&left);
    always_assert(mb.is_closed(), "the close did not close the mailbox");
    always_assert(left.is_empty(), "an empty mailbox handed something back");

    // QUIET. This is the step the rule is about, and joining is how to get it.
    worker.join()!!;
    always_assert(lf.returned.load(ACQUIRE) == 1, "the receiver did not return");
    always_assert(mb.is_quiet(), "the mailbox is closed but not quiet after the join");

    // FREED.
    mb.release();
}

<*
 **The ordinary correct shape: close with `out`, then join, then release.**

 Three senders, three outers each. The senders are joined first, so every send
 has returned before the close runs; the close hands back all nine; releasing
 those outers is the caller's work and it is done before the release rather than
 after it. Then, and only then, the mailbox is quiet and can be freed.

 This is the shape the reference tells a caller to write, run rather than
 reasoned about.
*>
fn void close_then_join_then_release() @test
{
    Mailbox* mb = new_mailbox();

    Sending[3] sd;
    Thread[3]  senders;
    foreach (usz i, &t : senders)
    {
        sd[i].mb = mb;
        sd[i].first = (int)(i * 3);
        t.create(&sender_fn, &sd[i])!!;
    }
    foreach (&t : senders) t.join()!!;

    InnerQueue left;
    mb.close(&left);

    // the caller's work, Part 11.6, and it happens before the release
    usz back = 0;
    while (Inner* inner = left.pop_front()) { back++; }
    always_assert(back == 9, "the close did not hand back every outer that was sent");

    always_assert(mb.is_quiet(), "a joined mailbox is not quiet");
    mb.release();
}

struct Sending
{
    Mailbox* mb;
    int      first;
    Msg[3]   outers;
}

fn int sender_fn(void* arg)
{
    Sending* sd = (Sending*)arg;
    foreach (usz k, &one : sd.outers)
    {
        mtk::helper::init(one);
        one.id = sd.first + (int)k;
        Slot s;
        s.fill(mtk::helper::to_inner(one));
        if (catch sd.mb.send(&s)) { always_assert(false, "an open mailbox refused a send"); }
    }
    return 0;
}
