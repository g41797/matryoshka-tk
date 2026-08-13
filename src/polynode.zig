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
//! The second variant omits create() and destroy(). A type opts into it with
//! `no_create_destroy`. Everything else is identical.
//!
//! Examples:
//! https://g41797.github.io/matryoshka-tk/examples/polynode/
//!
//! The three together:
//! https://g41797.github.io/matryoshka-tk/examples/flow/
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

/// "Container" for ItemHandle.
pub const Slot = ?ItemHandle;

/// Clears the intrusive list links.
///
/// Call after removing a node from a list.
///
/// Fix laziness of std.DoubleLinkedList
///
/// By hand only after reaching through ItemList._list.\
/// popFirst, popLast and remove call it for you.
pub inline fn reset(node: *PolyNode) void {
    node.node.prev = null;
    node.node.next = null;
}

/// True if the node has neighbours.
///
/// Not a membership test. The only member of a list has no neighbours,
/// so this returns false for it.
///
/// Every `!is_linked` assert in the toolkit inherits that blind spot.
///
/// - It catches the multi-element case.
/// - That is where most double-sends land.
/// - Nothing repairs it. State kept in an item cannot validate this.
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
            pub inline fn fromPoly(node: *PolyNode) ?*T {
                if (node.tag != TAG)
                    return null;

                return @fieldParentPtr("poly", node);
            }

            /// Same as fromPoly().
            ///
            /// Panics on type mismatch.
            pub inline fn mustFromPoly(node: *PolyNode) *T {
                return fromPoly(node) orelse unreachable;
            }

            /// Reach the PolyNode embedded in T.
            ///
            /// The inverse of fromPoly().\
            /// Cannot fail — T is known at compile time.\
            /// Never modifies the item.
            pub inline fn toPoly(self: *T) *PolyNode {
                return &self.poly;
            }

            /// Cast to T through the Slot holding it.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// Does not empty the Slot.
            pub inline fn fromSlot(slot: *const Slot) ?*T {
                const node = slot.* orelse return null;
                return fromPoly(node);
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
            ///
            /// Asserts the item has no neighbours. Take it out of its list
            /// first.
            pub inline fn moveFromSlot(slot: *Slot) ?*T {
                const node = slot.* orelse return null;
                const item = fromPoly(node) orelse return null;

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

                slot.* = Self.toPoly(item);
            }

            /// Destroys the item stored in the Slot.
            ///
            /// Does nothing if the Slot is empty. Safe as a defer target
            /// placed before the item exists.
            ///
            /// Asserts the item has no neighbours.
            ///
            /// The Slot is emptied before the item is released. A second
            /// destroy on the same Slot then does nothing.
            pub fn destroy(
                allocator: std.mem.Allocator,
                slot: *Slot,
            ) void {
                const poly = slot.* orelse return;

                std.debug.assert(!is_linked(poly));

                const item = Self.fromPoly(poly);
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
            pub inline fn fromPoly(node: *PolyNode) ?*T {
                if (node.tag != TAG)
                    return null;

                return @fieldParentPtr("poly", node);
            }

            /// Same as fromPoly().
            ///
            /// Panics on type mismatch.
            pub inline fn mustFromPoly(node: *PolyNode) *T {
                return fromPoly(node) orelse unreachable;
            }

            /// Reach the PolyNode embedded in T.
            ///
            /// The inverse of fromPoly().\
            /// Cannot fail — T is known at compile time.\
            /// Never modifies the item.
            pub inline fn toPoly(self: *T) *PolyNode {
                return &self.poly;
            }

            /// Cast to T through the Slot holding it.
            ///
            /// Returns null if the Slot is empty or holds another type.\
            /// Does not empty the Slot.
            pub inline fn fromSlot(slot: *const Slot) ?*T {
                const node = slot.* orelse return null;
                return fromPoly(node);
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
            ///
            /// Asserts the item has no neighbours. Take it out of its list
            /// first.
            pub inline fn moveFromSlot(slot: *Slot) ?*T {
                const node = slot.* orelse return null;
                const item = fromPoly(node) orelse return null;

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

/// Relatively safe double linked list of ItemHandle
///
/// Under runtime safety every insert asserts twice on the new item.
///
/// - This list does not already hold it. A walk, comparing addresses.
/// - The item has no neighbours. A read of the item.
///
/// Neither check alone is enough.
///
/// - The walk sees the list of one that is_linked cannot.
/// - is_linked sees a *different* list that the walk cannot.
/// - Together they cover more.
///
/// The walk makes an insert O(n) under safety builds. Nothing outside them.
pub const ItemList = struct {
    /// Takes the first item out.
    ///
    /// Returns null if the list is empty.\
    /// The returned item is never linked — reset() is called for you.
    pub inline fn popFirst(self: *ItemList) ?ItemHandle {
        const node = self._list.popFirst() orelse return null;
        const ih: ItemHandle = @fieldParentPtr("node", node);
        reset(ih);
        return ih;
    }

    /// Takes the last item out.
    ///
    /// Returns null if the list is empty.\
    /// The returned item is never linked — reset() is called for you.
    pub inline fn popLast(self: *ItemList) ?ItemHandle {
        const node = self._list.pop() orelse return null;
        const ih: ItemHandle = @fieldParentPtr("node", node);
        reset(ih);
        return ih;
    }

    /// Takes one item out, wherever it sits.
    ///
    /// Asserts the item is in this list.\
    /// The removed item is never linked — reset() is called for you.
    pub inline fn remove(self: *ItemList, ih: ItemHandle) void {
        if (std.debug.runtime_safety) std.debug.assert(self._holds(ih));
        self._list.remove(&ih.node);
        reset(ih);
    }

    /// First item, or null if the list is empty.
    ///
    /// The item stays in the list.
    pub inline fn first(self: *const ItemList) ?ItemHandle {
        const node = self._list.first orelse return null;
        const ih: ItemHandle = @fieldParentPtr("node", node);
        return ih;
    }

    /// Last item, or null if the list is empty.
    ///
    /// The item stays in the list.
    pub inline fn last(self: *const ItemList) ?ItemHandle {
        const node = self._list.last orelse return null;
        const ih: ItemHandle = @fieldParentPtr("node", node);
        return ih;
    }

    /// True if this list already holds the item.
    ///
    /// Compares node addresses. Never reads the item.
    fn _holds(self: *const ItemList, ih: ItemHandle) bool {
        var it = self._list.first;
        while (it) |n| : (it = n.next) if (n == &ih.node) return true;
        return false;
    }

    /// Asserts the item can be inserted into this list.
    ///
    /// _holds sees this list. is_linked sees any list, except the one
    /// holding it alone. Neither is complete. Together they cover more.
    ///
    /// std.DoublyLinkedList checks nothing. This is where it is checked.
    inline fn _checkInsert(self: *const ItemList, ih: ItemHandle) void {
        if (std.debug.runtime_safety) {
            std.debug.assert(!self._holds(ih));
            std.debug.assert(!is_linked(ih));
        }
    }

    /// Adds the item at the end.
    pub inline fn append(self: *ItemList, ih: ItemHandle) void {
        self._checkInsert(ih);
        self._list.append(&ih.node);
    }

    /// Adds the item at the front.
    pub inline fn prepend(self: *ItemList, ih: ItemHandle) void {
        self._checkInsert(ih);
        self._list.prepend(&ih.node);
    }

    /// Adds the item at the end and empties the Slot.
    ///
    /// Asserts the Slot is not empty. An append is not a defer target, so it
    /// follows a send rather than a put.
    pub fn appendFromSlot(self: *ItemList, slot: *Slot) void {
        std.debug.assert(slot.* != null);
        self.append(slot.*.?);
        slot.* = null;
    }

    /// Adds the item at the front and empties the Slot.
    ///
    /// Asserts the Slot is not empty. A prepend is not a defer target, so it
    /// follows a send rather than a put.
    pub fn prependFromSlot(self: *ItemList, slot: *Slot) void {
        std.debug.assert(slot.* != null);
        self.prepend(slot.*.?);
        slot.* = null;
    }

    /// Adds the item right after one already in the list.
    ///
    /// Also asserts `existing` is in this list, and is not the item being
    /// inserted.
    pub inline fn insertAfter(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void {
        if (std.debug.runtime_safety) {
            std.debug.assert(existing != ih);
            std.debug.assert(self._holds(existing));
        }
        self._checkInsert(ih);
        self._list.insertAfter(&existing.node, &ih.node);
    }

    /// Adds the item right before one already in the list.
    ///
    /// Also asserts `existing` is in this list, and is not the item being
    /// inserted.
    pub inline fn insertBefore(self: *ItemList, existing: ItemHandle, ih: ItemHandle) void {
        if (std.debug.runtime_safety) {
            std.debug.assert(existing != ih);
            std.debug.assert(self._holds(existing));
        }
        self._checkInsert(ih);
        self._list.insertBefore(&existing.node, &ih.node);
    }

    /// True if the list holds no items.
    pub inline fn isEmpty(self: *const ItemList) bool {
        return self._list.first == null;
    }

    /// Number of items in the list.
    ///
    /// Forwards std's walk. O(n).
    ///
    /// Mailbox and pool keep their own counters for this reason. This never
    /// replaces them.
    pub inline fn len(self: *const ItemList) usize {
        return self._list.len();
    }

    /// Returns an iterator over the list.
    ///
    /// Removes nothing. Items stay linked.
    pub inline fn iterator(self: *const ItemList) Iterator {
        return .{ ._next = self._list.first };
    }

    /// Moves every item of `other` to the end of this list.
    ///
    /// `other` is left empty.
    ///
    /// Asserts `other` is not this list, then returns early on the same list
    /// twice. Outside safety builds the assert is unreachable, and
    /// concatByMoving would ring the items and clear the header, losing every
    /// one of them.
    pub inline fn concat(self: *ItemList, other: *ItemList) void {
        std.debug.assert(self != other);
        if (self == other) return;
        self._list.concatByMoving(&other._list);
    }

    /// Takes the contents of a std list.
    ///
    /// The source is left empty. O(1).
    ///
    /// Asserts the std header it is handed is consistent — first and last both
    /// null, or both set.
    ///
    /// There is no copy form. A header copy aliases the same items.
    pub fn moveFromList(list: *std.DoublyLinkedList) ItemList {
        if (std.debug.runtime_safety)
            std.debug.assert((list.first == null) == (list.last == null));

        const moved: ItemList = .{ ._list = list.* };
        list.* = .{};
        return moved;
    }

    /// Move the contents to a std list.
    ///
    /// This list is left empty. O(1).
    ///
    /// There is no copy form. A header copy aliases the same items.
    pub fn moveToList(self: *ItemList) std.DoublyLinkedList {
        const moved = self._list;
        self._list = .{};
        return moved;
    }

    /// Iterator over an ItemList.
    pub const Iterator = struct {
        _next: ?*std.DoublyLinkedList.Node,

        /// Next item, or null at the end.
        pub inline fn next(self: *Iterator) ?ItemHandle {
            const node = self._next orelse return null;
            self._next = node.next;
            const ih: ItemHandle = @fieldParentPtr("node", node);
            return ih;
        }
    };

    /// Don't use it directly.\
    /// Use the methods below.
    ///
    /// Using of this field allowed for tests.
    ///
    /// An item taken out this way keeps its old prev/next. popFirst did not
    /// run, so reset did not either — call reset yourself.
    ///
    /// std.DoublyLinkedList.popFirst does not clear the links.
    /// ItemList.popFirst does.
    ///
    /// Skipping reset gives false positives from is_linked, and assert
    /// failures in the mailbox and pool guards.
    ///
    _list: std.DoublyLinkedList = .{},
};

const std = @import("std");
