// SPDX-FileCopyrightText: Copyright (c) 2026 g41797
// SPDX-License-Identifier: MIT

//! Toolkit for concurrent Zig systems.
//!
//! Components:
//! - polynode: runtime type identification and intrusion
//! - mailbox: item passing
//! - pool: item lifecycle management

pub const polynode = @import("polynode.zig");
pub const mailbox = @import("mailbox.zig");
pub const pool = @import("pool.zig");

const std = @import("std");
