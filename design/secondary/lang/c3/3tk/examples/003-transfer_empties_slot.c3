<*
 A transfer leaves the Slot empty, whichever way the outer went.

 - Send a `Holder` through a mailbox.
 - Put a `Holder` into a pool.
 - Move a `Holder` out of a Slot by hand.
 - Push a `Holder` onto a queue from a Slot.
 - Each Slot is empty right after its transfer.
*>
module shc::transfer_empties_slot;
import mtk;
import mtk::managed;
import mtk::mailbox;
import mtk::pool;
import shc::outers;
import shc::helpers;

faultdef TRANSFER_FAILED;

struct AlwaysCreateHooks (PoolHooks)
{
    Allocator alloc;
}

fn void AlwaysCreateHooks.on_get(&self, typeid want, usz in_pool, Slot* slot) @dynamic
{
    if (catch mtk::managed::create(Holder, self.alloc, slot)) return;
}

fn void AlwaysCreateHooks.on_put(&self, usz in_pool, Slot* slot, InnerQueue* extra) @dynamic {}

fn void AlwaysCreateHooks.on_close(&self, InnerQueue remaining) @dynamic
{
    while (Handle h = remaining.pop_front())
    {
        Slot s;
        s.fill(h);
        mtk::managed::release(Holder, &s);
    }
}

fn void? demonstrate_transfer_empties_slot(Allocator a)
{
    Mailbox* mb = mtk::mailbox::create(a)!;
    defer
    {
        InnerQueue left;
        mb.close(&left);
        while (Handle h = left.pop_front())
        {
            Slot s;
            s.fill(h);
            mtk::managed::release(Holder, &s);
        }
        mb.release();
    }

    AlwaysCreateHooks hooks = { .alloc = a };
    typeid[1] tags = { Holder::typeid };
    Pool* p = mtk::pool::create(a, &tags, &hooks)!;
    defer { p.close(); p.release(); }

    InnerQueue q;
    defer
    {
        while (Handle h = q.pop_front())
        {
            Slot s;
            s.fill(h);
            mtk::managed::release(Holder, &s);
        }
    }

    Slot to_send;
    defer mtk::managed::release(Holder, &to_send);
    mtk::managed::create(Holder, a, &to_send)!;
    mb.send(&to_send)!;
    shc::helpers::expect(TRANSFER_FAILED, to_send.is_empty(), "send left the Slot full")!;

    Slot to_put;
    defer mtk::managed::release(Holder, &to_put);
    mtk::managed::create(Holder, a, &to_put)!;
    p.put(&to_put);
    shc::helpers::expect(TRANSFER_FAILED, to_put.is_empty(), "put left the Slot full")!;

    Slot to_move;
    defer mtk::managed::release(Holder, &to_move);
    mtk::managed::create(Holder, a, &to_move)!;
    Holder* moved = to_move.move(Holder);
    shc::helpers::expect(TRANSFER_FAILED, to_move.is_empty(), "move left the Slot full")!;
    shc::helpers::expect(TRANSFER_FAILED, moved != null, "move gave back null")!;
    alloc::free(a, moved);

    Slot to_queue;
    defer mtk::managed::release(Holder, &to_queue);
    mtk::managed::create(Holder, a, &to_queue)!;
    q.push_back_slot(&to_queue);
    shc::helpers::expect(TRANSFER_FAILED, to_queue.is_empty(), "push_back_slot left the Slot full")!;
}

//----------------------
// Little-endian imports
//----------------------
import std::core::mem::alloc;
