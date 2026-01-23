const std = @import("std");
const mdz = @import("mdz");

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    std.debug.assert(args.skip() == true);
    const path = args.next() orelse return error.MissingFileInputArgument;

    const file = try Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    var reader_buf: [std.wasm.page_size]u8 = undefined;
    var file_reader = file.reader(io, &reader_buf);

    var writer_buf: [std.wasm.page_size / 4]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &writer_buf);

    const len = try mdz.parseMDZ(&file_reader.interface, &stdout_writer.interface);
    std.log.debug("{d} bytes written to stdout.", .{len});
}
