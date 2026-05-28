// MIT License

// Copyright (c) 2026 vExcess

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");
const posix = std.posix;
const vexlib = @import("vexlib");
const As = vexlib.As;

pub const UDP = @import("./udp.zig");

pub const IPv8Error = error {
    PacketTooSmall,
    PacketTooLarge
};

pub const Protocol = .{
    .ICMP = 1,
    .IGMP = 2,
    .TCP = 6,
    .UDP = 17,
    .ENCAP = 41,
    .OSPF = 89,
    .SCTP = 132
};

pub const Flags = struct {
    reserved: bool,
    dontFragment: bool,
    moreFragments: bool
};

pub const IPv8Header = struct {
    version: u4 = 8,
    ihl: u4,
    tos: u8,
    totalLength: u16,
    identification: u16,
    flags: u3,
    fragmentOffset: u13,
    ttl: u8,
    protocol: u8,
    checksum: u16 = 0,
    src: [8]u8,
    dst: [8]u8,
};

const UIPv8Payload = union(enum) {
    bytes: []u8,
    udpPacket: UDP.UDPPacket
};

pub const IPv8Packet = struct {
    header: IPv8Header,
    payload: []u8,
    buffer: []u8,

    pub fn alloc(src: [8]u8, dst: [8]u8, payload: []u8, protocol: u8, flags: ?Flags) !IPv8Packet {
        var _flags: u3 = 0b010;
        if (flags) |f| {
            const r = @as(u3, @intFromBool(f.reserved));
            const d = @as(u3, @intFromBool(f.dontFragment));
            const m = @as(u3, @intFromBool(f.moreFragments));
            _flags = (r << 2) | (d << 1) | m;
        }

        const dataLength = 7*4 + payload.len;
        if (dataLength > 65535) {
            return IPv8Error.PacketTooLarge;
        }

        var packet = IPv8Packet{
            .header = IPv8Header{
                .version = 8,
                .ihl = 7,
                .tos = 0,
                .totalLength = As.u16T(dataLength),
                .identification = 0,
                .flags = _flags,
                .fragmentOffset = 0,
                .ttl = 64,
                .protocol = protocol,
                .checksum = 0,
                .src = src,
                .dst = dst,
            },
            .payload = payload,
            .buffer = try vexlib.allocatorPtr.*.alloc(u8, dataLength)
        };

        _= try packet.writeToBuffer(packet.buffer);
        const headerLen = As.usize(packet.header.ihl) * 4;
        packet.payload = packet.buffer[headerLen..packet.header.totalLength];

        return packet;
    }

    pub fn dealloc(self: *IPv8Packet) void {
        vexlib.allocatorPtr.*.free(self.buffer);
    }

    pub fn fromBuffer(buffer: []u8) !IPv8Packet {
        if (buffer.len < 20) return IPv8Error.PacketTooSmall;

        var srcBuffer: [8]u8 = undefined;
        var dstBuffer: [8]u8 = undefined;
        if (buffer.len >= 28) {
            srcBuffer = [8]u8{
                buffer[12], buffer[13], buffer[14], buffer[15], // ipv4 part of address
                buffer[20], buffer[21], buffer[22], buffer[23] // ipv8 part of address
            };
            dstBuffer = [8]u8{
                buffer[16], buffer[17], buffer[18], buffer[19], // ipv4 part of address
                buffer[24], buffer[25], buffer[26], buffer[27] // ipv8 part of address
            };
        } else {
            srcBuffer = [8]u8{
                buffer[12], buffer[13], buffer[14], buffer[15], // ipv4 part of address
                0, 0, 0, 0
            };
            dstBuffer = [8]u8{
                buffer[16], buffer[17], buffer[18], buffer[19], // ipv4 part of address
                0, 0, 0, 0
            };
        }

        var packet = IPv8Packet{
            .header = IPv8Header{
                .version = @as(u4, @truncate(buffer[0] >> 4)),
                .ihl = @as(u4, @truncate(buffer[0])),
                .tos = buffer[1],
                .totalLength = std.mem.readInt(u16, buffer[2..4], .big),
                .identification = std.mem.readInt(u16, buffer[4..6], .big),
                .flags = @as(u3, @truncate(buffer[6] >> 5)),
                .fragmentOffset = @as(u13, @truncate(std.mem.readInt(u16, buffer[6..8], .big) & 0b0001111111111111)),
                .ttl = buffer[8],
                .protocol = buffer[9],
                .checksum = std.mem.readInt(u16, buffer[10..12], .big),
                .src = srcBuffer,
                .dst = dstBuffer,
            },
            .payload = undefined,
            .buffer = undefined
        };

        const totalLength = packet.header.totalLength;
        if (buffer.len < totalLength) return IPv8Error.PacketTooSmall;
        
        packet.buffer = try vexlib.allocatorPtr.*.alloc(u8, totalLength);
        @memcpy(packet.buffer, buffer[0..totalLength]);
        const headerLen = As.usize(packet.header.ihl) * 4;
        packet.payload = packet.buffer[headerLen..totalLength];

        return packet;
    }

    pub fn writeToBuffer(self: *const IPv8Packet, buffer: []u8) !usize {
        buffer[0] = (As.u8(self.header.version) << 4) | self.header.ihl;
        buffer[1] = self.header.tos;
        std.mem.writeInt(u16, buffer[2..4], self.header.totalLength, .big);
        std.mem.writeInt(u16, buffer[4..6], self.header.identification, .big);
        std.mem.writeInt(u16, buffer[6..8], (As.u16(self.header.flags) << 13) | As.u16(self.header.fragmentOffset), .big);
        buffer[8] = self.header.ttl;
        buffer[9] = self.header.protocol;
        // checksum must be set to 0 before checksum calculation
        std.mem.writeInt(u16, buffer[10..12], 0, .big);
        @memcpy(buffer[12..16], self.header.src[0..4]);
        @memcpy(buffer[20..24], self.header.src[4..8]);
        @memcpy(buffer[16..20], self.header.dst[0..4]);
        @memcpy(buffer[24..28], self.header.dst[4..8]);
        @memcpy(buffer[28..(28 + self.payload.len)], self.payload);
        std.mem.writeInt(u16, buffer[10..12], self.header.checksum, .big);

        return 28 + self.payload.len;
    }

    pub fn ipv4ify(self: *IPv8Packet) void {
        // set the IP version to 4
        self.buffer[0] = (self.buffer[0] & 0b00001111) | (As.u8(4) << 4);
        self.header.version = 4;

        // set the reserved flag bit
        self.buffer[6] = self.buffer[6] | 0b10000000;
        self.header.flags = @as(u3, @truncate(self.buffer[6] >> 5));

        // recalculate checksum
        // checksum must be set to 0 before checksum calculation
        std.mem.writeInt(u16, self.buffer[10..12], 0, .big);
        const checksum = self.calcChecksum();
        std.mem.writeInt(u16, self.buffer[10..12], checksum, .big);
    }

    // Port of https://github.com/stm32duino/LwIP/blob/main/src/core/inet_chksum.c LWIP_CHKSUM_ALGORITHM #1
    // (i ain't readin' allat https://datatracker.ietf.org/doc/html/rfc1071)
    pub fn calcChecksum(self: *const IPv8Packet) u16 {
        // Copyright (c) 2001, 2002 Swedish Institute of Computer Science.
        // All rights reserved.
        // 
        // Redistribution and use in source and binary forms, with or without modification,
        // are permitted provided that the following conditions are met:
        // 
        // 1. Redistributions of source code must retain the above copyright notice,
        //    this list of conditions and the following disclaimer.
        // 2. Redistributions in binary form must reproduce the above copyright notice,
        //    this list of conditions and the following disclaimer in the documentation
        //    and/or other materials provided with the distribution.
        // 3. The name of the author may not be used to endorse or promote products
        //    derived from this software without specific prior written permission.
        // 
        // THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
        // WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
        // MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
        // SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
        // EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
        // OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
        // INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
        // CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
        // IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
        // OF SUCH DAMAGE.

        var acc: u32 = 0;
        var src: u16 = undefined;
        var octetIdx: usize = 0;
        const headerLen = As.usize(self.header.ihl) * 4;
        var len = headerLen;

        // dataptr may be at odd or even addresses
        while (len > 1) {
            // declare first octet as most significant
            // thus assume network order, ignoring host order
            src = As.u16(self.buffer[octetIdx]) << 8;
            octetIdx += 1;
            // declare second octet as least significant
            src |= self.buffer[octetIdx];
            octetIdx += 1;
            acc += src;
            len -= 2;
        }

        if (len > 0) {
            // accumulate remaining octet
            src = As.u16(self.buffer[octetIdx]) << 8;
            acc += src;
        }

        // add deferred carry bits
        acc = (acc >> 16) + (acc & 0x0000ffff);
        if ((acc & 0xffff0000) != 0) {
            acc = (acc >> 16) + (acc & 0x0000ffff);
        }

        return ~As.u16T(acc);
    }

    pub fn print(self: *const IPv8Packet) void {
        const s = self.header.src;
        const d = self.header.dst;
        std.debug.print("{s}", .{"IPv8Packet{\n"});
        std.debug.print("    .header = {s}", .{"IPv8Header{\n"});
        std.debug.print("        .version = {d},\n", .{self.header.version});
        std.debug.print("        .ihl = {d},\n", .{self.header.ihl});
        std.debug.print("        .tos = {d},\n", .{self.header.tos});
        std.debug.print("        .totalLength = {d},\n", .{self.header.totalLength});
        std.debug.print("        .identification = {d},\n", .{self.header.identification});
        std.debug.print("        .flags = {b:0>3},\n", .{self.header.flags});
        std.debug.print("        .fragmentOffset = {d},\n", .{self.header.fragmentOffset});
        std.debug.print("        .ttl = {d},\n", .{self.header.ttl});
        std.debug.print("        .protocol = {d},\n", .{self.header.protocol});
        std.debug.print("        .checksum = {d},\n", .{self.header.checksum});
        std.debug.print("        .src = {d}.{d}.{d}.{d}.{d}.{d}.{d}.{d},\n", .{
            s[0],s[1],s[2],s[3],s[4],s[5],s[6],s[7]
        });
        std.debug.print("        .dst = {d}.{d}.{d}.{d}.{d}.{d}.{d}.{d},\n", .{
            d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]
        });
        std.debug.print("{s}", .{"    }\n"});
        std.debug.print("    .payload = {s}\n", .{self.payload});
        std.debug.print("{s}", .{"}\n"});
    }
};

pub fn addrEql(a: [8]u8, b: [8]u8) bool {
    var i: usize = 0; while (i < 8) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

pub const Handler = *const fn(IPv8Packet)void;

pub const Listener = struct {
    addr: [8]u8,
    port: u16,
    handler: Handler
};

pub const IPv8Server = struct {
    socket: posix.socket_t,
    listeners: vexlib.ArrayList(Listener),
    thread: ?std.Thread,
    running: bool,

    pub fn init() !IPv8Server {
        // listen on layer 2 for all layer 3 packets
        // this is necessary to get the packet before it is touched by Linux's layer 3 network layer
        // because Linux's layer 3 will clear the Option fields that the IPv8 address bits are stored in
        const ETH_P_ALL = std.mem.nativeToBig(u16, 3); // Swaps 0x0003 to Big Endian
        const socket = try posix.socket(posix.AF.PACKET, posix.SOCK.DGRAM, ETH_P_ALL);
        const listeners = vexlib.ArrayList(Listener).alloc(2);

        return IPv8Server{
            .socket = socket,
            .listeners = listeners,
            .thread = null,
            .running = true
        };
    }

    pub fn listen(self: *IPv8Server, addr: [8]u8, port: u16, handler: Handler) !void {
        if (self.thread == null) {
            self.thread = try std.Thread.spawn(.{}, IPv8Server.listenerLoop, .{self});
        }
        self.listeners.append(Listener{
            .addr = addr,
            .port = port,
            .handler = handler
        });
    }

    fn listenerLoop(self: *IPv8Server) !void {
        var buffer: [65535]u8 = undefined;

        while (self.running) {
            var addr: std.os.linux.sockaddr.ll = undefined;
            var addrLen: posix.socklen_t = @sizeOf(std.os.linux.sockaddr.ll);

            // blocking call that reads packet with metadata
            const bytesReceived = try posix.recvfrom(self.socket, &buffer, 0, @ptrCast(&addr), &addrLen);

            const PACKET_OUTGOING = 4;
            if (addr.pkttype == PACKET_OUTGOING) {
                continue; // ignore outgoing packets
            }

            const packetBuffer = buffer[0..bytesReceived];
            const packet = IPv8Packet.fromBuffer(packetBuffer) catch |err| {
                if (err == IPv8Error.PacketTooSmall) {
                    continue;
                } else {
                    return err;
                }
            };

            if (packet.header.version == 8 or packet.header.flags & 0b100 == 0b100) {
                {var i: u32 = 0; while (i < self.listeners.len) : (i += 1) {
                    const listener = self.listeners.get(i);
                    if (addrEql(packet.header.dst, listener.addr)) {
                        const isUDP = packet.header.protocol == Protocol.UDP;
                        if (listener.port == 0 or (isUDP and (try UDP.UDPPacket.fromBuffer(packet.payload)).dstPort == listener.port)) {
                            listener.handler(packet);    
                        }
                    }
                }}
            }
        }
    }

    pub fn close(self: *IPv8Server) void {
        self.running = false;
        if (self.thread != null) {
            self.thread.?.detach();
        }
        posix.close(self.socket);
    }
};
