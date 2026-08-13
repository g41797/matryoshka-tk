// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Toolkit for concurrent Zig systems.
//!
//! Components:
//! - polynode: runtime type identification and intrusion
//! - mailbox: item passing
//! - pool: item reuse through your hooks
//!
//! Full documentation:
//! https://g41797.github.io/matryoshka-tk/
//!
//! Examples:
//! https://g41797.github.io/matryoshka-tk/examples/
//!
//! The three together:
//! https://g41797.github.io/matryoshka-tk/examples/flow/
//!
pub const polynode = @import("polynode.zig");
pub const mailbox = @import("mailbox.zig");
pub const pool = @import("pool.zig");

/// A mailbox. Application code keeps `*Mbox`.
pub const Mbox = mailbox.Mbox;

/// A pool. Application code keeps `*Pool`.
pub const Pool = pool.Pool;

const std = @import("std");
