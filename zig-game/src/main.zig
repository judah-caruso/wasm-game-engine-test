const std = @import("std");
const math = std.math;

const Rng = std.rand.DefaultPrng;

extern "env" fn EngineLog(str: [*]const u8, size: u32) void;
extern "env" fn EngineFps() f32;
extern "env" fn EngineTps() f32;
extern "env" fn EngineExit() void;

extern "env" fn GfxClear(r: f32, g: f32, b: f32, a: f32) void;
extern "env" fn GfxImage(x: f32, y: f32, r: f32, g: f32, b: f32, a: f32) void;
extern "env" fn GfxRectangle(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) void;
extern "env" fn GfxText(str: [*]const u8, size: u32, x: f32, y: f32) void;

extern "env" fn InputPressed(input: i32) i32;
extern "env" fn InputCursorX() f32;
extern "env" fn InputCursorY() f32;

const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1,
};

const Engine = struct {
    pub inline fn log(msg: []const u8) void {
        EngineLog(msg.ptr, msg.len);
    }

    pub inline fn fps() f32 {
        return EngineFps();
    }

    pub inline fn tps() f32 {
        return EngineTps();
    }

    pub inline fn exit() void {
        EngineExit();
    }
};

const Input = struct {
    pub inline fn pressed(input: i32) bool {
        return InputPressed(input) == 1;
    }

    pub inline fn cursorX() f32 {
        return InputCursorX();
    }

    pub inline fn cursorY() f32 {
        return InputCursorY();
    }
};

const Gfx = struct {
    pub inline fn clear(c: Color) void {
        GfxClear(c.r, c.g, c.b, c.a);
    }

    pub inline fn image(x: f32, y: f32, overlay: Color) void {
        GfxImage(x, y, overlay.r, overlay.g, overlay.b, overlay.a);
    }

    pub inline fn rectangle(x: f32, y: f32, w: f32, h: f32, c: Color) void {
        GfxRectangle(x, y, w, h, c.r, c.g, c.b, c.a);
    }

    pub inline fn text(txt: []const u8, x: f32, y: f32) void {
        GfxText(txt.ptr, txt.len, x, y);
    }
};

const gravity: f32 = 0.0981;
const startingGophers: i32 = 1_000;
const gophersPerClick: i32 = 1000;
const spriteW: f32 = 27;
const spriteH: f32 = 29;

const Gopher = struct {
    px: f32 = 10,
    py: f32 = 10,
    vx: f32 = 0,
    vy: f32 = 0,
    c: Color = .{ 1, 1, 1, 1 },
};

const colors = [_]Color{
    .{ 1, 0.25, 0.25, 0.75 },
    .{ 0.25, 1, 0.25, 0.65 },
    .{ 0.25, 0.25, 1, 0.70 },
};

var gophers: std.ArrayList(Gopher) = undefined;
var rng: std.rand.Xoshiro256 = undefined;
var alloc = std.heap.wasm_allocator;
var tmp_arena: std.heap.ArenaAllocator = undefined;
var tmp_alloc: std.mem.Allocator = undefined;

export fn setup() callconv(.C) void {
    Engine.log("Setup");

    tmp_arena = std.heap.ArenaAllocator.init(alloc);
    tmp_alloc = tmp_arena.allocator();

    rng = Rng.init(0);
    gophers = std.ArrayList(Gopher).init(alloc);

    var i: usize = 0;
    while (i < startingGophers) : (i += 1) {
        var idx = rng.random().uintLessThan(u32, colors.len);
        gophers.append(.{
            .vx = rng.random().float(f32) * 5,
            .vy = rng.random().float(f32) * 5,
            .c = colors[idx],
        }) catch unreachable;
    }
}

export fn teardown() callconv(.C) void {
    Engine.log("Teardown");

    // @note(judah): wasm can't actually free memory?
    gophers.deinit();
    tmp_arena.deinit();
}

export fn update() callconv(.C) void {
    if (Input.pressed(1)) {
        Engine.exit();
        return;
    }

    _ = tmp_arena.reset(.retain_capacity);

    const sw = 640;
    const sh = 480;

    const mx = Input.cursorX();
    const my = Input.cursorY();

    if (Input.pressed(2)) {
        const amt: usize = @intCast(gophersPerClick);
        var new = gophers.addManyAsArray(amt) catch unreachable;
        for (new) |*g| {
            var idx = rng.random().uintLessThan(u32, colors.len);
            g.* = .{
                .px = mx,
                .py = my,
                .vx = rng.random().float(f32) * 5,
                .vy = rng.random().float(f32) * 5,
                .c = colors[idx],
            };
        }
    }

    for (gophers.items) |*g| {
        g.vy += gravity;
        g.px += g.vx;
        g.py += g.vy;

        if (g.py >= sh - spriteH) {
            g.vy *= 0.85 / 2.0;
            if (rng.random().float(f32) > 0.5) {
                g.vy -= rng.random().float(f32) * 8;
            }
        } else if (g.py < 0) {
            g.vy = -g.vy;
        }

        if (g.px > sw - spriteW) {
            g.vx = -math.fabs(g.vx);
        } else if (g.px < 0) {
            g.vx = math.fabs(g.vx);
        }
    }
}

export fn render() callconv(.C) void {
    Gfx.clear(.{ 0.19, 0.19, 0.19, 1 });

    for (gophers.items) |g| {
        Gfx.image(g.px, g.py, g.c);
    }

    const fps = Engine.fps();
    const tps = Engine.tps();

    var fps_str = std.fmt.allocPrint(tmp_alloc, "fps: {d:.2}", .{fps}) catch unreachable;
    var tps_str = std.fmt.allocPrint(tmp_alloc, "tps: {d:.2}", .{tps}) catch unreachable;
    var g_str = std.fmt.allocPrint(tmp_alloc, "gophers: {}", .{gophers.items.len}) catch unreachable;

    Gfx.rectangle(10, 10, 125, 55, .{ 0, 0, 0, 0.5 });
    Gfx.text("lang: zig", 10, 10);
    Gfx.text(fps_str, 10, 24);
    Gfx.text(tps_str, 10, 36);
    Gfx.text(g_str, 10, 48);
}
