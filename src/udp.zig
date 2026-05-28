const std = @import("std");

const vexlib = @import("vexlib");
const As = vexlib.As;

pub const UDPError = error{
    PacketTooSmall,
};

pub const UDPPacket = struct {
    srcPort: u16,
    dstPort: u16,
    length: u16,
    checksum: u16,
    payload: []u8,

    pub fn alloc(srcPort: u16, dstPort: u16, payload: []u8) UDPPacket {
        const length = As.u16T(8 + payload.len);
        return UDPPacket{
            .srcPort = srcPort,
            .dstPort = dstPort,
            .length = length,
            .checksum = 0, // In standard IP, this requires a pseudo-header calculation
            .payload = payload,
        };
    }

    pub fn fromBuffer(buffer: []u8) !UDPPacket {
        if (buffer.len < 8) {
            return UDPError.PacketTooSmall;
        }

        const len = std.mem.readInt(u16, buffer[4..6], .big);

        if (buffer.len < len) {
            return UDPError.PacketTooSmall;
        }

        return UDPPacket{
            .srcPort = std.mem.readInt(u16, buffer[0..2], .big),
            .dstPort = std.mem.readInt(u16, buffer[2..4], .big),
            .length = len,
            .checksum = std.mem.readInt(u16, buffer[6..8], .big),
            .payload = buffer[8..len],
        };
    }

    pub fn writeToBuffer(self: *const UDPPacket, buffer: []u8) !usize {
        std.mem.writeInt(u16, buffer[0..2], self.srcPort, .big);
        std.mem.writeInt(u16, buffer[2..4], self.dstPort, .big);
        std.mem.writeInt(u16, buffer[4..6], self.length, .big);
        std.mem.writeInt(u16, buffer[6..8], self.checksum, .big);
        @memcpy(buffer[8..(8 + self.payload.len)], self.payload);

        return 8 + self.payload.len;
    }
};