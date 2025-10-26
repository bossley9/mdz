const std = @import("std");
const mdz = @import("./mdz/parser.zig");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.next();
    const path = args.next() orelse {
        return error.MissingFileInputArgument;
    };

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var reader_buf: [std.wasm.page_size]u8 = undefined;
    var file_reader = file.reader(&reader_buf);

    var writer_buf: [std.wasm.page_size / 4]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&writer_buf);

    _ = try mdz.parseMDZ(&file_reader.interface, &stdout_writer.interface);
}

comptime {
    _ = @import("./mdz/specification.zig");
}
test {
    std.testing.refAllDecls(@This());
}
