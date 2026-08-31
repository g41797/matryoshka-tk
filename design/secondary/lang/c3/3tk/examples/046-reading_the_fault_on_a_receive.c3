<*
 CLOSED, WOKEN and TIMEOUT are three different reasons `receive` returned
 empty-handed, and a worker that treats one as another leaves work behind
 or spins forever.

 - An empty, open mailbox with a short window reports TIMEOUT.
 - `wake_all` on a mailbox with nothing queued reports WOKEN.
 - A closed mailbox reports CLOSED.
*>
module exm::reading_the_fault_on_a_receive;
import mtk;
import mtk::mailbox;
import exm::helpers;
import std::thread;
import std::time;
import std::atomic::types;

faultdef READING_THE_FAULT_FAILED;

fn void? p46_receive_faults(Mailbox* mb)
{
    while (true)
    {
        Slot s;
        if (catch f = mb.receive(&s, time::ms(250)))
        {
            if (f == mtk::CLOSED)  return;            // end of stream — leave cleanly
            if (f == mtk::WOKEN)   continue;          // a poke — look at the state and keep waiting
            if (f == mtk::TIMEOUT) continue;          // the window passed — your domain decides
            return f~;
        }
    }
}

fn void? timeout_is_not_closed_or_woken(Mailbox* mb)
{
    Slot s;
    if (catch f = mb.receive(&s, time::ms(50)))
    {
        exm::helpers::expect(READING_THE_FAULT_FAILED, f == mtk::TIMEOUT, "an empty, open mailbox with a short window reports TIMEOUT")!;
        return;
    }
    return READING_THE_FAULT_FAILED~;
}

struct WokenArgs
{
    Mailbox* mb;
    Atomic{bool}* saw_woken;
}

fn int block_and_report_woken(void* arg)
{
    WokenArgs* a = (WokenArgs*)arg;
    Slot s;
    if (catch f = a.mb.receive(&s, time::ms(2000)))
    {
        a.saw_woken.store(f == mtk::WOKEN, RELEASE);
    }
    return 0;
}

fn void? woken_is_not_closed_or_timeout(Mailbox* mb)
{
    Atomic{bool} saw_woken;
    saw_woken.store(false, RELEASE);

    WokenArgs args = { .mb = mb, .saw_woken = &saw_woken };
    Thread receiver;
    receiver.create(&block_and_report_woken, &args)!!;

    thread::sleep(time::ms(100))!!;   // give the receiver time to block
    mb.wake_all()!;
    receiver.join()!!;

    exm::helpers::expect(READING_THE_FAULT_FAILED, saw_woken.load(ACQUIRE), "a wake with nothing queued reports WOKEN")!;
}

fn void? closed_is_not_woken_or_timeout(Mailbox* mb)
{
    InnerQueue left;
    mb.close(&left);
    Slot s;
    if (catch f = mb.receive(&s, time::ms(2000)))
    {
        exm::helpers::expect(READING_THE_FAULT_FAILED, f == mtk::CLOSED, "a closed mailbox reports CLOSED")!;
        return;
    }
    return READING_THE_FAULT_FAILED~;
}
