const std = @import("std");
const io = @import("io.zig");
const String = @import("String.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || io.Error || String.Error || error{
    TokenNotFound,
    BadStringFormat,
    StringNotEnding,
    UnknownCharacterIdentifier,
};

pub const OpenCloseToken = enum {
    Close,
    Open,
};

pub const Token = union(enum) {
    // Misc
    Identifier: String,
    String: String,
    StringStart,
    StringEnd,

    // Keywords
    Import,
    Public,
    Function,
    As,
    Var,
    Type,
    Static,
    And,
    Or,

    // Arithmetic Operations
    Add,
    Sub,
    Mul,
    Div,
    Mod,

    // Binary Operations
    BNot,
    BAnd,
    BOr,
    BXor,
    LShift,
    RShift,
    Ref,
    Deref,

    // Signs
    ColonSep,
    DotSep,
    Equal,
    Not,
    /// ()
    Bracket: OpenCloseToken,
    /// []
    SBracket: OpenCloseToken,
    /// <>
    TBracket: OpenCloseToken,
    /// {}
    Brace: OpenCloseToken,
};

const TokenizeState = struct {
    allocator: *Allocator,
    tokenList: *std.ArrayList(Token),
    token: *String,
    src: []const u8,
    currIndex: u32 = 0,
};

fn tokenOf(state: *TokenizeState) Error!Token {
    var token = state.token;
    const hashOf = String.hashOf;

    return switch (token.hash()) {
        hashOf("import") => .{ .Import = {} },
        hashOf("pub") => .{ .Public = {} },
        hashOf("fn") => .{ .Function = {} },
        hashOf("as") => .{ .As = {} },
        hashOf("var") => .{ .Var = {} },
        hashOf("type") => .{ .Type = {} },
        hashOf("static") => .{ .Static = {} },
        hashOf("and") => .{ .And = {} },
        hashOf("or") => .{ .Or = {} },
        else => .{ .Identifier = try token.clone() },
    };
}

inline fn stringParse(state: *TokenizeState) Error!void {
    var tokenList = state.tokenList;

    var str = state.token;
    str.clear();

    const writer = str.writer();

    var i: u32 = state.currIndex;
    const src = state.src;
    if (src[i] == '"') i += 1;

    (try tokenList.addOne()).* = .{ .StringStart = {} };

    while (i < src.len) : (i += 1) {
        const c = src[i];
        const nc: u8 = if (i + 1 < src.len) src[i + 1] else 255;

        switch (c) {
            '\\' => {
                switch (nc) {
                    '\\' => try writer.writeByte(nc),
                    '/' => try writer.writeByte(nc),
                    'n' => try writer.writeByte('\n'),
                    'r' => try writer.writeByte('\r'),
                    '$' => try writer.writeByte(nc),
                    else => return Error.BadStringFormat,
                }
                i += 1;
            },
            '"' => {
                if (!str.isEmpty()) {
                    (try tokenList.addOne()).* = .{ .String = try str.clone() };
                    str.clear();
                }
                (try tokenList.addOne()).* = .{ .StringEnd = {} };
                str.clear();
                state.currIndex = i;

                return;
            },
            '\n', '\r' => return Error.BadStringFormat,
            '$' => {
                if (nc != '(') return Error.BadStringFormat;
                var content = String.init(state.allocator.*);
                defer content.deinit();

                var j: u32 = i + 2;
                while (j < src.len) : (j += 1) {
                    const c2 = src[j];
                    if (c2 == ')') break;
                    try content.writer().writeByte(c2);
                }

                const nTokens = try tokenize(state.allocator.*, content.str());
                defer state.allocator.free(nTokens);
                if (!str.isEmpty()) {
                    (try tokenList.addOne()).* = .{ .String = try str.clone() };
                    str.clear();
                }
                if (nTokens.len > 0)
                    try tokenList.appendSlice(nTokens);

                i = j;
            },
            else => try writer.writeByte(c),
        }
    }

    return Error.StringNotEnding;
}
inline fn characterParse(state: *TokenizeState, char: u8, nchar: u8) Error!void {
    var tokenList = state.tokenList;
    var token = state.token;

    const writer = token.writer();

    switch (char) {
        '"', ' ', ';', '\n', '\r', '\'', '(', ')', '[', ']', '{', '}', '<', '>', ':', '.', '=', '!', '+', '-', '*', '/', '%', '&', '$' => {
            if (!token.isEmpty()) {
                (try tokenList.addOne()).* = try tokenOf(state);
                token.clear();
            }
        },
        else => {},
    }
    switch (char) {
        ' ', ';', '\n', '\r' => {
            // Add line feed things for debugging
        },
        '"' => try stringParse(state),
        '\'' => {
            try writer.writeByte(nchar);
            (try tokenList.addOne()).* = try tokenOf(state);
        },
        '(', ')' => {
            (try tokenList.addOne()).* = .{
                .Bracket = if (char == '(') .Open else .Close,
            };
        },
        '{', '}' => {
            (try tokenList.addOne()).* = .{
                .Brace = if (char == '{') .Open else .Close,
            };
        },
        '[', ']' => {
            (try tokenList.addOne()).* = .{
                .SBracket = if (char == '[') .Open else .Close,
            };
        },
        '<', '>' => {
            (try tokenList.addOne()).* = .{
                .SBracket = if (char == '<') .Open else .Close,
            };
        },
        ':' => {
            (try tokenList.addOne()).* = .{
                .ColonSep = {},
            };
        },
        '.' => {
            (try tokenList.addOne()).* = .{
                .DotSep = {},
            };
        },
        '=' => {
            (try tokenList.addOne()).* = .{
                .Equal = {},
            };
        },
        '!' => {
            (try tokenList.addOne()).* = .{
                .Not = {},
            };
        },
        '+' => {
            (try tokenList.addOne()).* = .{
                .Add = {},
            };
        },
        '-' => {
            (try tokenList.addOne()).* = .{
                .Sub = {},
            };
        },
        '*' => {
            (try tokenList.addOne()).* = .{
                .Mul = {},
            };
        },
        '/' => {
            (try tokenList.addOne()).* = .{
                .Div = {},
            };
        },
        '%' => {
            (try tokenList.addOne()).* = .{
                .Mod = {},
            };
        },
        '&' => {
            (try tokenList.addOne()).* = .{
                .Ref = {},
            };
        },
        '$' => {
            (try tokenList.addOne()).* = .{
                .Deref = {},
            };
        },
        'a'...'z', 'A'...'Z', '0'...'9', '_' => {
            try writer.writeByte(char);
        },
        else => {
            try io.print("src[{d}] = {c}\n", .{ state.currIndex, char });
            return Error.UnknownCharacterIdentifier;
        },
    }
}

pub fn tokenize(allocator: Allocator, src: []const u8) Error![]Token {
    var tokenList = std.ArrayList(Token).init(allocator);
    defer tokenList.deinit();

    var token = String.init(allocator);
    defer token.deinit();

    var state = TokenizeState{
        .allocator = @constCast(&allocator),
        .tokenList = &tokenList,
        .token = &token,
        .src = src,
    };

    while (state.currIndex < src.len) : (state.currIndex += 1) {
        const i = state.currIndex;
        const c = src[i];
        const nc: u8 = if (i + 1 < src.len) src[i + 1] else 255;

        try characterParse(&state, c, nc);
    }

    if (!token.isEmpty()) {
        (try tokenList.addOne()).* = try tokenOf(&state);
        token.clear();
    }

    return tokenList.toOwnedSlice();
}

pub fn tokenizeFile(allocator: Allocator, filename: []const u8) Error![]Token {
    return tokenize(allocator, try io.readFile(allocator, filename));
}
