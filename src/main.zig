const std = @import("std");
const mod = @import("./root.zig");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.next();
    const path = args.next() orelse {
        return error.MissingFileInputArgument;
    };

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var reader_buf: [1024 * 64]u8 = undefined;
    var file_reader = file.reader(&reader_buf);
    var reader = &file_reader.interface;

    reader.fill(1024 * 64) catch |err| switch (err) {
        std.io.Reader.Error.EndOfStream => {},
        else => return err,
    };
    const input = reader.buffer[reader.seek..reader.end];

    var writer_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&writer_buf);

    _ = try mod.parseDjot(input, &stdout_writer.interface);
}

test {
    std.testing.refAllDecls(@This());
}
