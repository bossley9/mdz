const std = @import("std");
const mod = @import("./root.zig");
comptime {
    // include unreferenced tests
    _ = @import("./djot/specification.zig");
}

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

    _ = try mod.parseDjot(&file_reader.interface, &stdout_writer.interface);
}

test {
    std.testing.refAllDecls(@This());
}
