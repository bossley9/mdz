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

    var writer_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&writer_buf);

    _ = try mod.parseDjot(&file_reader.interface, &stdout_writer.interface);
}

test {
    std.testing.refAllDecls(@This());
}
