const std = @import("std");
const mdz = @import("mdz");

const Io = std.Io;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    var threaded = Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingFileInputArgument;

    const file = try Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    var reader_buf: [std.wasm.page_size]u8 = undefined;
    var file_reader = file.reader(io, &reader_buf);

    var writer_buf: [std.wasm.page_size / 4]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &writer_buf);

    _ = try mdz.parseMDZ(&file_reader.interface, &stdout_writer.interface);
}
