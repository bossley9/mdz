const std = @import("std");
const mod = @import("./root.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        return error.MissingFileInputArgument;
    }

    const file = try std.fs.openFileAbsolute(args[1], .{});
    defer file.close();

    var reader_buf: [1024]u8 = undefined;
    var file_reader = file.reader(&reader_buf);

    var writer_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&writer_buf);

    _ = try mod.parseDjot(&file_reader.interface, &stdout_writer.interface);
}

test {
    std.testing.refAllDecls(@This());
}
