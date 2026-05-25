const std = @import("std");

const ipv8 = @import("ipv8");
const IPv8Packet = ipv8.IPv8Packet;
const IPv8Server = ipv8.IPv8Server;

const vexlib = @import("vexlib");

fn handler(packet: IPv8Packet) void {
    std.debug.print("Packet Received ({d} bytes)\n", .{packet.buffer.len});

    // Verify Checksum
    const checksum = packet.calcChecksum();
    if (checksum == 0) {
        std.debug.print("Checksum is valid\n", .{});
    } else {
        std.debug.print("Packet is CORRUPTED\n", .{});
    }

    packet.print();
}

pub fn main() !void {
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    var server = try IPv8Server.init();
    defer server.close();

    try server.listen(.{127,0,0,1,0,0,0,1}, 0, handler);
    std.debug.print("IPv8 server listening on 127.0.0.1.0.0.0.1\n", .{});

    server.thread.?.join();
}