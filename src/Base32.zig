//! Root library file that exposes the public API.

const std = @import("std");
const log = std.log.scoped(.Base32);

const STD_PAD = '=';
const STD_SET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const HEX_SET = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
const CROCKFORD_SET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// Standard Base32 encoding without padding.
pub const STD_NO_PAD_ENC = Base32.init(STD_SET);

/// Crockford Base32 encoding.
pub const CROCKFORD_ENC = Base32.init(CROCKFORD_SET);

/// Standard Base32 encoding.
pub const STD_ENC = Base32.initWithPadding(STD_SET, STD_PAD);

/// Hex Base32 encoding.
pub const HEX_ENC = Base32.initWithPadding(HEX_SET, STD_PAD);

const Base32 = @This();

buf: [32]u8,
dec_map: [256]u8,
pad_char: ?u8 = null,

pub const Error = error{
    NewLinesNotAllowed,
    NotEnoughSpace,
    CorruptInput,
};

/// Initializes a Base32 encoding without padding.
pub fn init(str: []const u8) Base32 {
    return initWithPadding(str, null);
}

/// Initializes a Base32 encoding with padding.
pub fn initWithPadding(str: []const u8, pad_char: ?u8) Base32 {
    std.debug.assert(str.len == 32);

    if (pad_char) |c| {
        std.debug.assert(!(c == 'r' or c == '\n' or c > 0xFF));
    }

    return .{
        .buf = blk: {
            var buf: [32]u8 = undefined;
            @memcpy(buf[0..], str);
            break :blk buf;
        },
        .dec_map = blk: {
            var dec_map = [1]u8{0xFF} ** 256;
            for (str, 0..) |c, i| {
                dec_map[@intCast(c)] = @intCast(i);
            }
            break :blk dec_map;
        },
        .pad_char = pad_char,
    };
}

/// Returns the Base32 encoded string length.
pub fn encodeLen(self: Base32, n: usize) usize {
    if (self.pad_char) |_| {
        return (n + 4) / 5 * 8;
    }
    return (n * 8 + 4) / 5;
}

/// Encodes the `source` as Base32-formatted string and outputs into `dest`.
pub fn encode(self: Base32, dest: []u8, source: []const u8) []const u8 {
    var dst = dest;
    var src = source;
    var n: usize = 0;
    while (src.len > 0) {
        var b = [_]u8{0} ** 8;
        switch (src.len) {
            1 => {
                case1(b[0..], src);
            },
            2 => {
                case2(b[0..], src);
                case1(b[0..], src);
            },
            3 => {
                case3(b[0..], src);
                case2(b[0..], src);
                case1(b[0..], src);
            },
            4 => {
                case4(b[0..], src);
                case3(b[0..], src);
                case2(b[0..], src);
                case1(b[0..], src);
            },
            else => {
                b[7] = src[4] & 0x1F;
                b[6] = src[4] >> 5;
                case4(b[0..], src);
                case3(b[0..], src);
                case2(b[0..], src);
                case1(b[0..], src);
            },
        }

        const size = dst.len;
        if (size >= 8) {
            dst[0] = self.buf[b[0] & 31];
            dst[1] = self.buf[b[1] & 31];
            dst[2] = self.buf[b[2] & 31];
            dst[3] = self.buf[b[3] & 31];
            dst[4] = self.buf[b[4] & 31];
            dst[5] = self.buf[b[5] & 31];
            dst[6] = self.buf[b[6] & 31];
            dst[7] = self.buf[b[7] & 31];
            n += 8;
        } else {
            var i: usize = 0;
            while (i < size) : (i += 1) {
                dst[i] = self.buf[b[i] & 31];
            }
            n += i;
        }

        if (src.len < 5) {
            if (self.pad_char == null) {
                break;
            }
            dst[7] = self.pad_char.?;
            if (src.len < 4) {
                dst[6] = self.pad_char.?;
                dst[5] = self.pad_char.?;
                if (src.len < 3) {
                    dst[4] = self.pad_char.?;
                    if (src.len < 2) {
                        dst[3] = self.pad_char.?;
                        dst[2] = self.pad_char.?;
                    }
                }
            }
            break;
        }

        src = src[5..];
        dst = dst[8..];
    }

    return dest[0..n];
}

/// Returns the Base32 decoded string length.
pub fn decodeLen(self: Base32, n: usize) usize {
    if (self.pad_char) |_| {
        return n / 8 * 5;
    }
    return n * 5 / 8;
}

/// Decodes the `source` as Base32-formatted string and outputs into `dest`.
pub fn decode(self: Base32, dest: []u8, source: []const u8) ![]const u8 {
    if (dest.len < self.decodeLen(source.len)) {
        return error.NotEnoughSpace;
    }

    for (source) |c| {
        if (c == '\r' or c == '\n') {
            return error.NewLinesNotAllowed;
        }
    }

    const dst = dest;
    var src = source;
    var n: usize = 0;
    const orig_src_len = src.len;
    var dst_idx: usize = 0;
    var is_end: bool = false;
    while (src.len > 0 and !is_end) {
        var dbuf = [_]u8{0} ** 8;
        var dlen: usize = 8;
        var j: usize = 0;
        while (j < 8) {
            if (src.len == 0) {
                if (self.pad_char) |_| {
                    return error.MissingPadding;
                }
                dlen = j;
                is_end = true;
                break;
            }

            const in = src[0];
            src = src[1..];
            if (self.pad_char != null and in == self.pad_char.? and j >= 2 and src.len < 8) {
                if (src.len + j < 8 - 1) {
                    log.warn("incorrect input at {d}\n", .{orig_src_len});
                    return error.NotEnoughPadding;
                }

                var k: usize = 0;
                while (k < 8 - 1 - j) : (k += 1) {
                    if (src.len > k and self.pad_char != null and src[k] != self.pad_char.?) {
                        log.warn("incorrect input at {d}\n", .{orig_src_len - src.len + k - 1});
                        return error.IncorrectPadding;
                    }
                }

                dlen = j;
                is_end = true;
                if (dlen == 1 or dlen == 3 or dlen == 6) {
                    log.warn("incorrect input at {d}\n", .{orig_src_len - src.len - 1});
                    return error.IncorrectPadding;
                }
                break;
            }

            dbuf[j] = self.dec_map[in];
            if (dbuf[j] == 0xFF) {
                log.warn("{d} {d}\n", .{ in, self.dec_map[in] });
                for (self.dec_map, 0..) |m, idx| {
                    log.warn("== {d} ={X}\n", .{ idx, m });
                }
                log.warn("incorrect input at {d}\n", .{orig_src_len - src.len - 1});
                return error.CorruptInput;
            }

            j += 1;
        }

        switch (dlen) {
            8 => {
                dec8(dst, dst_idx, dbuf[0..]);
                dec7(dst, dst_idx, dbuf[0..]);
                dec5(dst, dst_idx, dbuf[0..]);
                dec4(dst, dst_idx, dbuf[0..]);
                dec2(dst, dst_idx, dbuf[0..]);
                n += 5;
            },
            7 => {
                dec7(dst, dst_idx, dbuf[0..]);
                dec5(dst, dst_idx, dbuf[0..]);
                dec4(dst, dst_idx, dbuf[0..]);
                dec2(dst, dst_idx, dbuf[0..]);
                n += 4;
            },
            5 => {
                dec5(dst, dst_idx, dbuf[0..]);
                dec4(dst, dst_idx, dbuf[0..]);
                dec2(dst, dst_idx, dbuf[0..]);
                n += 3;
            },
            4 => {
                dec4(dst, dst_idx, dbuf[0..]);
                dec2(dst, dst_idx, dbuf[0..]);
                n += 2;
            },
            2 => {
                dec2(dst, dst_idx, dbuf[0..]);
                n += 1;
            },
            else => {},
        }

        dst_idx += 5;
    }

    return dest[0..n];
}

fn dec2(dst: []u8, dst_idx: usize, dbuf: []u8) void {
    dst[dst_idx] = dbuf[0] << 3 | dbuf[1] >> 2;
}

fn dec4(dst: []u8, dst_idx: usize, dbuf: []u8) void {
    dst[dst_idx + 1] = dbuf[1] << 6 | dbuf[2] << 1 | dbuf[3] >> 4;
}

fn dec5(dst: []u8, dst_idx: usize, dbuf: []u8) void {
    dst[dst_idx + 2] = dbuf[3] << 4 | dbuf[4] >> 1;
}

fn dec7(dst: []u8, dst_idx: usize, dbuf: []u8) void {
    dst[dst_idx + 3] = dbuf[4] << 7 | dbuf[5] << 2 | dbuf[6] >> 3;
}

fn dec8(dst: []u8, dst_idx: usize, dbuf: []u8) void {
    dst[dst_idx + 4] = dbuf[6] << 5 | dbuf[7];
}

fn case1(b: []u8, src: []const u8) void {
    b[1] |= (src[0] << 2) & 0x1F;
    b[0] = src[0] >> 3;
}

fn case2(b: []u8, src: []const u8) void {
    b[3] |= (src[1] << 4) & 0x1F;
    b[2] = (src[1] >> 1) & 0x1F;
    b[1] = (src[1] >> 6) & 0x1F;
}

fn case3(b: []u8, src: []const u8) void {
    b[4] |= (src[2] << 1) & 0x1F;
    b[3] = (src[2] >> 4) & 0x1F;
}

fn case4(b: []u8, src: []const u8) void {
    b[6] |= (src[3] << 3) & 0x1F;
    b[5] = (src[3] >> 2) & 0x1F;
    b[4] = src[3] >> 7;
}

const Test = struct {
    decoded: []const u8,
    encoded: []const u8,
};

const tests = [_]Test{
    .{ .decoded = "", .encoded = "" },
    .{ .decoded = "f", .encoded = "MY======" },
    .{ .decoded = "fo", .encoded = "MZXQ====" },
    .{ .decoded = "foo", .encoded = "MZXW6===" },
    .{ .decoded = "foob", .encoded = "MZXW6YQ=" },
    .{ .decoded = "fooba", .encoded = "MZXW6YTB" },
    .{ .decoded = "sure.", .encoded = "ON2XEZJO" },
    .{ .decoded = "sure", .encoded = "ON2XEZI=" },
    .{ .decoded = "sur", .encoded = "ON2XE===" },
    .{ .decoded = "su", .encoded = "ON2Q====" },
    .{ .decoded = "leasure.", .encoded = "NRSWC43VOJSS4===" },
    .{ .decoded = "easure.", .encoded = "MVQXG5LSMUXA====" },
    .{ .decoded = "easure.", .encoded = "MVQXG5LSMUXA====" },
    .{ .decoded = "asure.", .encoded = "MFZXK4TFFY======" },
    .{ .decoded = "sure.", .encoded = "ON2XEZJO" },
};

test "encode/decode" {
    var buf: [1024]u8 = undefined;
    for (tests) |t| {
        const enc_len = STD_ENC.encodeLen(t.decoded.len);
        const encoded = STD_ENC.encode(buf[0..enc_len], t.decoded);
        try std.testing.expectEqualSlices(u8, t.encoded, encoded);

        const dec_len = STD_ENC.decodeLen(t.encoded.len);
        const decoded = try STD_ENC.decode(buf[0..dec_len], t.encoded);
        try std.testing.expectEqualSlices(u8, t.decoded, decoded);
    }
}

test "encode/decode without padding" {
    var buf: [1024]u8 = undefined;
    for (tests) |t| {
        const enc_len = STD_NO_PAD_ENC.encodeLen(t.decoded.len);
        const dec_len = STD_NO_PAD_ENC.decodeLen(t.encoded.len);
        const encoded = STD_NO_PAD_ENC.encode(buf[0..enc_len], t.decoded);
        const encoded_end = std.mem.indexOfScalar(u8, t.encoded, '=') orelse t.encoded.len;
        try std.testing.expectEqualSlices(u8, t.encoded[0..encoded_end], encoded);

        const decoded = try STD_NO_PAD_ENC.decode(buf[0..dec_len], t.encoded[0..encoded_end]);
        try std.testing.expectEqualSlices(u8, t.decoded, decoded);
    }
}
