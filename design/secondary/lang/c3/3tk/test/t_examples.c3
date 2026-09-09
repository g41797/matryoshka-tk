<*
 The wrappers for `examples/`, one `@test` per example, across the eleven
 groups: `shc::a_slot_and_transfer`, `shc::b_cleanup`, `shc::c_crossing`,
 `shc::d_dispatch`, `shc::e_infrastructure`, `shc::f_mailbox`,
 `shc::g_topology`, `shc::h_pool`, `shc::i_shutdown`, `shc::j_coordinator`
 and `shc::k_new_in_3tk`.

 Every example is called by one `@test` here, and `always_assert` appears in
 this file and nowhere in `examples/`.

 `import shc;` reaches every example: C3 imports a module's submodules with
 it, two levels deep, so this file gains no import when a group gains a file.
*>
module mtk_test;
import mtk;
import mtk::mailbox;
import mtk::pool;
import shc;
import shc::outers;
import std::core::mem::alloc;

fn void test_example_empty_slot() @test
{
    if (catch f = shc::a_slot_and_transfer::empty_slot::acquire_into_an_empty_slot(mem)) always_assert(false, "empty_slot example failed");
}

fn void test_example_transfer_empties_slot() @test
{
    if (catch f = shc::a_slot_and_transfer::transfer_empties_slot::demonstrate_transfer_empties_slot(mem)) always_assert(false, "transfer_empties_slot example failed");
}

fn void test_example_insert_from_slot() @test
{
    if (catch f = shc::a_slot_and_transfer::insert_from_slot::insert_from_a_slot(mem)) always_assert(false, "insert_from_slot example failed");
}

fn void test_example_null_safe_cleanup() @test
{
    if (catch f = shc::b_cleanup::null_safe_cleanup::cleanup_survives_an_empty_slot(mem)) always_assert(false, "null_safe_cleanup example failed");
}

fn void test_example_defer_put_early() @test
{
    if (catch f = shc::b_cleanup::defer_put_early::defer_put_goes_before_the_get(mem)) always_assert(false, "defer_put_early example failed");
}

fn void test_example_defer_release_early() @test
{
    if (catch f = shc::b_cleanup::defer_release_early::defer_release_goes_before_the_create(mem)) always_assert(false, "defer_release_early example failed");
}

fn void test_example_defer_for_received_outer() @test
{
    if (catch f = shc::b_cleanup::defer_for_received_outer::defer_covers_both_paths(mem)) always_assert(false, "defer_for_received_outer example failed");
}

fn void test_example_refused_put_fallback() @test
{
    if (catch f = shc::b_cleanup::refused_put_fallback::fallback_releases_what_the_pool_refused(mem)) always_assert(false, "refused_put_fallback example failed");
}

fn void test_example_no_raw_allocator_call() @test
{
    if (catch f = shc::b_cleanup::no_raw_allocator_call::never_a_raw_allocator_call(mem)) always_assert(false, "no_raw_allocator_call example failed");
}

fn void test_example_embedding_the_inner() @test
{
    if (catch f = shc::c_crossing::embedding_the_inner::embed_one_inner_anywhere(mem)) always_assert(false, "embedding_the_inner example failed");
}

fn void test_example_type_crossing() @test
{
    if (catch f = shc::c_crossing::type_crossing::cross_with_dollar_type(mem)) always_assert(false, "type_crossing example failed");
}

fn void test_example_recovering_the_type() @test
{
    if (catch f = shc::c_crossing::recovering_the_type::recover_four_ways(mem)) always_assert(false, "recovering_the_type example failed");
}

fn void test_example_walk_a_batch() @test
{
    if (catch f = shc::c_crossing::walk_a_batch::walk_a_received_batch(mem)) always_assert(false, "walk_a_batch example failed");
}

fn void test_example_reach_into_a_full_slot() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::c_crossing::reach_into_a_full_slot::reach_in_then_send(mem, mb)) always_assert(false, "reach_into_a_full_slot example failed");
}

fn void test_example_dispatch_outer_first() @test
{
    if (catch f = shc::d_dispatch::dispatch_outer_first::dispatch_releases_every_identity(mem)) always_assert(false, "dispatch_outer_first example failed");
}

fn void test_example_dispatch_identity_first() @test
{
    if (catch f = shc::d_dispatch::dispatch_identity_first::get_one_of_each_then_close(mem)) always_assert(false, "dispatch_identity_first example failed");
}

fn void test_example_dispatch_switch() @test
{
    if (catch f = shc::d_dispatch::dispatch_switch::dispatch_by_switch(mem)) always_assert(false, "dispatch_switch example failed");
}

fn void test_example_dispatch_table() @test
{
    if (catch f = shc::d_dispatch::dispatch_table::dispatch_same_identity_two_ways(mem)) always_assert(false, "dispatch_table example failed");
}

fn void test_example_infrastructure_wrapper() @test
{
    Mailbox* to = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; to.close(&left); to.release(); }
    Mailbox* inbox = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; inbox.close(&left); inbox.release(); }
    if (catch f = shc::e_infrastructure::infrastructure_wrapper::wrapper_carries_the_job_id(mem, to, inbox)) always_assert(false, "infrastructure_wrapper example failed");
}

fn void test_example_mailbox_as_message() @test
{
    if (catch f = shc::e_infrastructure::mailbox_as_message::a_travelling_mailbox_stays_open(mem)) always_assert(false, "mailbox_as_message example failed");
}

fn void test_example_worker_finish_signal() @test
{
    if (catch f = shc::e_infrastructure::worker_finish_signal::finish_signal_is_a_real_pointer_check(mem)) always_assert(false, "worker_finish_signal example failed");
}

fn void test_example_pool_as_message() @test
{
    if (catch f = shc::e_infrastructure::pool_as_message::a_travelling_pool_carries_its_policy(mem)) always_assert(false, "pool_as_message example failed");
}

fn void test_example_poll() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::f_mailbox::poll::poll_then_send_then_poll(mem, mb)) always_assert(false, "poll example failed");
}

fn void test_example_receive_all() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::f_mailbox::receive_all::receive_all_at_once(mem, mb)) always_assert(false, "receive_all example failed");
}

fn void test_example_out_of_band() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::f_mailbox::out_of_band::oob_arrives_first(mem, mb)) always_assert(false, "out_of_band example failed");
}

fn void test_example_close_recovery() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    if (catch f = shc::f_mailbox::close_recovery::close_recovers_what_is_left(mem, mb)) always_assert(false, "close_recovery example failed");
}

fn void test_example_release_a_refused_transfer() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    if (catch f = shc::f_mailbox::release_a_refused_transfer::refused_send_is_released_by_the_caller(mem, mb)) always_assert(false, "release_a_refused_transfer example failed");
}

fn void test_example_wake_without_a_message() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::f_mailbox::wake_without_a_message::wake_reaches_a_blocked_receiver(mb)) always_assert(false, "wake_without_a_message example failed");
}

fn void test_example_request_response() @test
{
    Mailbox* req_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; req_mbx.close(&left); req_mbx.release(); }
    Mailbox* resp_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; resp_mbx.close(&left); resp_mbx.release(); }
    if (catch f = shc::g_topology::request_response::one_request_one_response(mem, req_mbx, resp_mbx)) always_assert(false, "request_response example failed");
}

fn void test_example_pipeline() @test
{
    Mailbox* in_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; in_mbx.close(&left); in_mbx.release(); }
    Mailbox* out_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; out_mbx.close(&left); out_mbx.release(); }
    if (catch f = shc::g_topology::pipeline::values_cross_one_stage_doubled(mem, in_mbx, out_mbx)) always_assert(false, "pipeline example failed");
}

fn void test_example_fan_in() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::g_topology::fan_in::three_senders_one_mailbox(mem, mb)) always_assert(false, "fan_in example failed");
}

fn void test_example_fan_out() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    if (catch f = shc::g_topology::fan_out::each_outer_goes_to_exactly_one_worker(mem, mb)) always_assert(false, "fan_out example failed");
}

fn void test_example_available_or_new() @test
{
    if (catch f = shc::h_pool::available_or_new::reuse_before_create(mem)) always_assert(false, "available_or_new example failed");
}

fn void test_example_new_only() @test
{
    if (catch f = shc::h_pool::new_only::new_ignores_what_is_kept(mem)) always_assert(false, "new_only example failed");
}

fn void test_example_available_only() @test
{
    if (catch f = shc::h_pool::available_only::drain_stops_at_not_available(mem)) always_assert(false, "available_only example failed");
}

fn void test_example_seeding_a_fixed_size_pool() @test
{
    if (catch f = shc::h_pool::seeding_a_fixed_size_pool::seed_caps_the_pool(mem)) always_assert(false, "seeding_a_fixed_size_pool example failed");
}

fn void test_example_the_hook_object_is_the_context() @test
{
    if (catch f = shc::h_pool::the_hook_object_is_the_context::no_cast_needed(mem)) always_assert(false, "the_hook_object_is_the_context example failed");
}

fn void test_example_a_pool_of_several_identities() @test
{
    if (catch f = shc::h_pool::a_pool_of_several_identities::one_policy_three_identities(mem)) always_assert(false, "a_pool_of_several_identities example failed");
}

fn void test_example_reading_the_fault_on_a_receive() @test
{
    Mailbox* timeout_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; timeout_mbx.close(&left); timeout_mbx.release(); }
    if (catch f = shc::i_shutdown::reading_the_fault_on_a_receive::timeout_is_not_closed_or_woken(timeout_mbx)) always_assert(false, "reading_the_fault_on_a_receive (timeout) example failed");

    Mailbox* woken_mbx = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; woken_mbx.close(&left); woken_mbx.release(); }
    if (catch f = shc::i_shutdown::reading_the_fault_on_a_receive::woken_is_not_closed_or_timeout(woken_mbx)) always_assert(false, "reading_the_fault_on_a_receive (woken) example failed");

    Mailbox* closed_mbx = mtk::mailbox::create(mem)!!;
    defer closed_mbx.release();
    if (catch f = shc::i_shutdown::reading_the_fault_on_a_receive::closed_is_not_woken_or_timeout(closed_mbx)) always_assert(false, "reading_the_fault_on_a_receive (closed) example failed");
}

fn void test_example_the_coordinator() @test
{
    shc::j_coordinator::the_coordinator::CoordinatorHooks hooks;
    hooks.alloc = mem;
    typeid[1] tags = { shc::outers::Holder::typeid };
    Pool* p = mtk::pool::create(mem, &tags, &hooks)!!;
    Mailbox* mb = mtk::mailbox::create(mem)!!;

    shc::j_coordinator::the_coordinator::Master master = { .alloc = mem, .mbx = mb, .pool = p };
    if (catch f = master.run()) always_assert(false, "the_coordinator example failed");
}

fn void test_example_the_step() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::j_coordinator::the_step::one_step_one_name(mem, mb)) always_assert(false, "the_step example failed");
}

fn void test_example_acquiring_the_resources() @test
{
    if (catch f = shc::j_coordinator::acquiring_the_resources::resources_are_plain_pointers(mem)) always_assert(false, "acquiring_the_resources example failed");
}

fn void test_example_releasing_the_resources() @test
{
    if (catch f = shc::j_coordinator::releasing_the_resources::reverse_acquisition_order(mem)) always_assert(false, "releasing_the_resources example failed");
}

fn void test_example_the_thread_is_given_one_pointer() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::j_coordinator::the_thread_is_given_one_pointer::one_pointer_is_the_whole_context(mem, mb)) always_assert(false, "the_thread_is_given_one_pointer example failed");
}

fn void test_example_the_allocator_in_the_outer() @test
{
    if (catch f = shc::k_new_in_3tk::the_allocator_in_the_outer::the_outer_keeps_what_it_chose_to_keep(mem)) always_assert(false, "the_allocator_in_the_outer example failed");
}

fn void test_example_an_identity_costs_no_registration() @test
{
    Mailbox* mb = mtk::mailbox::create(mem)!!;
    defer { InnerQueue left; mb.close(&left); mb.release(); }
    if (catch f = shc::k_new_in_3tk::identity_costs_nothing::a_new_type_costs_nothing(mem, mb)) always_assert(false, "an_identity_costs_no_registration example failed");
}

fn void test_example_the_optional_declaration_walk() @test
{
    if (catch f = shc::k_new_in_3tk::the_optional_declaration_walk::the_declaration_is_the_condition(mem)) always_assert(false, "the_optional_declaration_walk example failed");
}

fn void test_example_guarding_an_expensive_check() @test
{
    if (catch f = shc::k_new_in_3tk::guarding_an_expensive_check::the_guard_costs_nothing_in_a_fast_build(mem)) always_assert(false, "guarding_an_expensive_check example failed");
}

fn void test_example_a_composite_outer_gives_back_its_parts() @test
{
    if (catch f = shc::k_new_in_3tk::composite_outer_gives_back::extra_is_taken_the_same_way_as_the_slot(mem)) always_assert(false, "a_composite_outer_gives_back_its_parts example failed");
}
