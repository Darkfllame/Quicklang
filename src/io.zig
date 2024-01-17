const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Error = std.fs.File.OpenError || std.fs.File.ReadError || std.fs.File.WriteError || Allocator.Error || error{
    StreamTooLong,
};

pub fn readFile(allocator: Allocator, filename: []const u8) Error![]const u8 {
    const file = try openFile(allocator, filename, .read_only);
    defer file.close();

    // 1 << 26 = 64 Mb
    return @errorCast(file.reader().readAllAlloc(allocator, 1 << 26));
}
pub fn print(comptime fmt: []const u8, args: anytype) Error!void {
    const stdOut = std.io.getStdOut();
    return @errorCast(stdOut.writer().print(fmt, args));
}

pub fn openFileWordingDir(filename: []const u8, mode: std.fs.File.OpenMode) Error!std.fs.File {
    const cwd = std.fs.cwd();

    return @errorCast(cwd.openFile(filename, .{ .mode = mode }));
}
pub fn openFileExeDir(allocator: Allocator, filename: []const u8, mode: std.fs.File.OpenMode) Error!std.fs.File {
    const dirPath = try @as(Error![]const u8, @errorCast(std.fs.selfExeDirPathAlloc(allocator)));
    defer allocator.free(dirPath);
    const fullPath = try std.mem.join(allocator, "/", &.{
        dirPath,
        filename,
    });
    defer allocator.free(fullPath);
    return std.fs.openFileAbsolute(fullPath, .{ .mode = mode });
}
pub fn openFile(allocator: Allocator, filename: []const u8, mode: std.fs.File.OpenMode) Error!std.fs.File {
    return openFileWordingDir(filename, mode) catch openFileExeDir(allocator, filename, mode);
}
