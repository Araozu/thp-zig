//! Generates IDs for the AST nodes

const std = @import("std");

var current_id: u64 = 0;

pub fn generate_id() u64 {
    const id = current_id;
    current_id += 1;
    return id;
}
