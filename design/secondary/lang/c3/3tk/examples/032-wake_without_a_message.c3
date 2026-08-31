<*
 A wake is not a close and not a send. Nothing is queued, so a blocked
 receiver that wakes for it has nothing to release — it goes back to check
 the flag that changed, not to an outer.

 - A receiver blocks on `receive` with a long timeout.
 - The main thread flips a flag and calls `wake_all`.
 - The receiver sees `WOKEN`, reads the flag, and returns.
*>
module exm::wake_without_a_message;
import mtk;
import mtk::mailbox;
import exm::helpers;
import std::thread;
import std::time;
import std::atomic::types;

faultdef WAKE_WITHOUT_A_MESSAGE_FAILED;

struct WakeArgs
{
    Mailbox* mb;
    Atomic{bool}* stopping;
    Atomic{bool}* saw_woken;
}

fn int wake_receiver(void* arg)
{
    WakeArgs* a = (WakeArgs*)arg;
    while (true)
    {
        Slot s;
        if (catch f = a.mb.receive(&s, time::ms(2000)))
        {
            if (f == mtk::WOKEN)
            {
                if (a.stopping.load(ACQUIRE))
                {
                    a.saw_woken.store(true, RELEASE);
                    return 0;
                }
                continue;
            }
            return 0;
        }
    }
}

fn void? wake_reaches_a_blocked_receiver(Mailbox* mb)
{
    Atomic{bool} stopping;
    Atomic{bool} saw_woken;
    stopping.store(false, RELEASE);
    saw_woken.store(false, RELEASE);

    WakeArgs args = { .mb = mb, .stopping = &stopping, .saw_woken = &saw_woken };
    Thread receiver;
    receiver.create(&wake_receiver, &args)!!;

    thread::sleep(time::ms(100))!!;   // give the receiver time to block

    stopping.store(true, RELEASE);
    mb.wake_all()!;

    receiver.join()!!;

    exm::helpers::expect(WAKE_WITHOUT_A_MESSAGE_FAILED, saw_woken.load(ACQUIRE), "the blocked receiver reported WOKEN")!;
    exm::helpers::expect(WAKE_WITHOUT_A_MESSAGE_FAILED, !mb.is_closed(), "a wake does not close the mailbox")!;
}
