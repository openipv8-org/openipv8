const std = @import("std");
const net = std.net;
const posix = std.posix;

const ipv8 = @import("ipv8");
const IPv8Packet = ipv8.IPv8Packet;

const vexlib = @import("vexlib");

pub fn main() !void {
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    const serverAddr = try net.Address.parseIp4("127.0.0.1", 3000);
    
    // socket to send raw IP packets (requires sudo)
    const socket: posix.socket_t = try posix.socket(serverAddr.any.family, posix.SOCK.RAW, posix.IPPROTO.RAW);
    defer posix.close(socket);

    // tell kernel that the IP header is included in our buffer
    const TRUE: i32 = 1;
    try posix.setsockopt(
        socket,
        posix.IPPROTO.IP,
        std.os.linux.IP.HDRINCL,
        std.mem.asBytes(&TRUE)
    );

    var payload = "Hello from IPv8!";
    var packet = try IPv8Packet.alloc(
        [8]u8{127,0,0,1,0,0,0,2},
        [8]u8{127,0,0,1,0,0,0,1},
        // ipv8.Protocol.UDP
        @constCast(payload[0..payload.len]), 253, null
    );

    packet.ipv4ify();

    std.debug.print("Packet Sending ({d} bytes)...\n", .{packet.buffer.len});
    packet.print();
    _ = try posix.sendto(socket, packet.buffer, 0, &serverAddr.any, serverAddr.getOsSockLen());
}