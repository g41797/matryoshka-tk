<*
 Part 8.7: an item already on THIS queue, and ALONE on it.

 **This program used to provoke the O(n) walk, and the walk is gone.** It was
 the WALK half of the old Part 8.6 pair: a queue of exactly one member left the
 item with no neighbours on either side, both of its link fields null, so the
 link test could not see it and only a walk of the container could. Part 8.6 said in so many
 words that neither check alone was enough, and D12 recorded the hole as an
 accepted cost.

 R6b closed it with no field. The last item of every chain points at ITSELF, so
 the sole item of a queue has `points_to() == this`, `is_linked` returns true,
 and the
 link test catches the case that used to need the walk. `contains` and the walk
 were deleted outright.

 What that changes for this program, exactly:

 - It still aborts in a checking build, but in the **link test** rather than in
   the walk, and at O(1) rather than O(n).
 - The check that catches it is **tier 2** now instead of tier 3. It compiles
   out under `--safe=no` like every other tier 2 check — the abort does not
   reach a fast build — but an ordinary safe build no longer pays a walk per
   insert to have it.

 Safe build: aborts in the tier 2 link test.
 Fast build: the queue is corrupted, silently. Exits 0 without walking it.
*>
module neg;
import mtk;
import std::io;

fn int main()
{
    Msg m;
    mtk::helper::init(&m);

    InnerQueue q;
    q.push_back(mtk::helper::to_handle(&m));
    q.push_back(mtk::helper::to_handle(&m));   // <-- the violation

    io::printn("no check: the item was inserted twice");
    return 0;
}
