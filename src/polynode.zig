// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Runtime type support for intrusive Matryoshka items.
//!
//! Every Matryoshka item embeds a PolyNode.
//!
//! PolyNode provides:
//! - intrusive list links
//! - runtime type identity
//!
//! PolyHelper(T) generates the helper functions for T.
//!
//! You don't need to deal with @fieldParentPtr.
//!
//! Several types/functions are shown twice, because the helper has 2 variants.
//!
//! No clue how to get rid of them. Be patient.
const _doc_stub = void;

/// Runtime type marker.
///
/// Each PolyNode-based type has one.\
/// Its address is the runtime type ID.
pub const PolyTag = struct {
    _: u8 = 0,
};

/// Alias of *PolyNode.
pub const ItemHandle = *PolyNode;

/// Embedded in every managed item.
///
/// Applications work with the parent item.
///
/// Two ways to name the same pointer:
/// - ItemHandle
///   - Mailbox and Pool carry items this way.
///   - Hold it. Send it. Put it in a Slot.
///   - Do not look inside.
/// - *PolyNode
///   - PolyHelper takes this.
///   - Where the node is opened.
///   - Read the tag. Reach the parent item.
///
/// Same type. Different intent.
pub const PolyNode = struct {
    node: std.DoublyLinkedList.Node = .{},
    tag: *const anyopaque = undefined,
};

/// Optional ItemHandle.
///
/// Think about it as ItemHandle' 'container'.
pub const Slot = ?ItemHandle;

/// Clears the intrusive list links.
///
/// Call after removing a node from a list.
///
/// Fix laziness of std.DoubleLinkedList
pub inline fn reset(node: *PolyNode) void {
    node.node.prev = null;
    node.node.next = null;
}

/// True if the node is linked into a list.
pub inline fn is_linked(node: *PolyNode) bool {
    return node.node.prev != null or node.node.next != null;
}

/// Generates runtime type support for `T`.
///
/// `T` must contain:
///
/// ```zig
/// poly: PolyNode
/// ```
///
/// Generated functions:
/// - runtime type ID
/// - type checks
/// - safe casts
/// - initialization
///
/// By default also generates:
/// - create()
/// - destroy()
///
/// Disable create() and destroy() generation with:
///
/// ```zig
/// const no_create_destroy = void{};
/// ```
pub fn PolyHelper(comptime T: type) type {
    comptime validatePolyType(T);

    if (!@hasDecl(T, "no_create_destroy")) {
        return struct {
            const Self = @This();

            var _tag: PolyTag = .{};

            /// Runtime type ID.
            pub const TAG: *const anyopaque = &_tag;

            /// True if the tag identifies T.
            pub inline fn isIt(tag: *const anyopaque) bool {
                return tag == TAG;
            }

            /// Cast to T through its embedded PolyNode.
            ///
            /// Returns null on type mismatch.\
            /// Never modifies the node.
            pub inline fn fromNode(node: *PolyNode) ?*T {
                if (node.tag != TAG)
                    return null;

                return @fieldParentPtr("poly", node);
            }

            /// Same as fromNode().
            ///
            /// Panics on type mismatch.
            pub inline fn mustFromNode(node: *PolyNode) *T {
                return fromNode(node) orelse unreachable;
            }

            /// Reach the PolyNode embedded in T.
            ///
            /// The inverse of fromNode().\
            /// Cannot fail — T is known at compile time.\
            /// Never modifies the item.
            pub inline fn toNode(self: *T) *PolyNode {
                return &self.poly;
            }

            /// Cast to T through the Slot holding it.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// Does not empty the Slot.
            pub inline fn fromSlot(slot: *const Slot) ?*T {
                const node = slot.* orelse return null;
                return fromNode(node);
            }

            /// Same as fromSlot().
            ///
            /// Panics on failure.
            pub inline fn mustFromSlot(slot: *const Slot) *T {
                return fromSlot(slot) orelse unreachable;
            }

            /// Takes T out of the Slot.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// On success the Slot is left empty.\
            /// On failure the Slot is unchanged.
            pub inline fn moveFromSlot(slot: *Slot) ?*T {
                const node = slot.* orelse return null;
                const item = fromNode(node) orelse return null;

                std.debug.assert(!is_linked(node));

                slot.* = null;

                return item;
            }

            /// Initializes the embedded PolyNode.
            pub inline fn init(self: *T) void {
                self.poly = .{
                    .node = .{},
                    .tag = TAG,
                };
            }

            /// Allocates and initializes T.
            ///
            /// Stores the item in the Slot.
            pub fn create(
                allocator: std.mem.Allocator,
                slot: *Slot,
            ) !void {
                std.debug.assert(slot.* == null);

                const item = try allocator.create(T);
                item.* = .{};
                Self.init(item);

                slot.* = Self.toNode(item);
            }

            /// Destroys the item stored in the Slot.
            ///
            /// Does nothing if the Slot is empty.
            pub fn destroy(
                allocator: std.mem.Allocator,
                slot: *Slot,
            ) void {
                const poly = slot.* orelse return;

                std.debug.assert(!is_linked(poly));

                const item = Self.fromNode(poly);
                std.debug.assert(item != null);

                // Clear the Slot before releasing the item.
                slot.* = null;

                allocator.destroy(item.?);
            }
        };
    } else {
        return struct {
            const Self = @This();

            var _tag: PolyTag = .{};

            /// Runtime type ID.
            pub const TAG: *const anyopaque = &_tag;

            /// True if the tag identifies T.
            pub inline fn isIt(tag: *const anyopaque) bool {
                return tag == TAG;
            }

            /// Cast to T through its embedded PolyNode.
            ///
            /// Returns null on type mismatch.\
            /// Never modifies the node.
            pub inline fn fromNode(node: *PolyNode) ?*T {
                if (node.tag != TAG)
                    return null;

                return @fieldParentPtr("poly", node);
            }

            /// Same as fromNode().
            ///
            /// Panics on type mismatch.
            pub inline fn mustFromNode(node: *PolyNode) *T {
                return fromNode(node) orelse unreachable;
            }

            /// Reach the PolyNode embedded in T.
            ///
            /// The inverse of fromNode().\
            /// Cannot fail — T is known at compile time.\
            /// Never modifies the item.
            pub inline fn toNode(self: *T) *PolyNode {
                return &self.poly;
            }

            /// Cast to T through the Slot holding it.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// Does not empty the Slot.
            pub inline fn fromSlot(slot: *const Slot) ?*T {
                const node = slot.* orelse return null;
                return fromNode(node);
            }

            /// Same as fromSlot().
            ///
            /// Panics on failure.
            pub inline fn mustFromSlot(slot: *const Slot) *T {
                return fromSlot(slot) orelse unreachable;
            }

            /// Takes T out of the Slot.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// On success the Slot is left empty.\
            /// On failure the Slot is unchanged.
            pub inline fn moveFromSlot(slot: *Slot) ?*T {
                const node = slot.* orelse return null;
                const item = fromNode(node) orelse return null;

                std.debug.assert(!is_linked(node));

                slot.* = null;

                return item;
            }

            /// Initializes the embedded PolyNode.
            pub inline fn init(self: *T) void {
                self.poly = .{
                    .node = .{},
                    .tag = TAG,
                };
            }
        };
    }
}

fn validatePolyType(comptime T: type) void {
    if (!@hasField(T, "poly"))
        @compileError(@typeName(T) ++ ": missing field 'poly: PolyNode'");

    if (@FieldType(T, "poly") != PolyNode)
        @compileError(@typeName(T) ++ ": field 'poly' must have type PolyNode");
}

const std = @import("std");
