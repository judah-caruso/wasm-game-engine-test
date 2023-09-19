use std::{self};

// @note(judah): I'm sure there's a more "rusty" way to do things,
// but this works for the demo.

mod input {
    #[link(wasm_import_module = "env")]
    extern "C" {
        fn InputPressed(input: i32) -> bool;
        fn InputCursorX() -> f32;
        fn InputCursorY() -> f32;
    }

    pub fn pressed(input: i32) -> bool {
        return unsafe { InputPressed(input) };
    }

    pub fn cursor_position() -> (f32, f32) {
        unsafe {
            let x = InputCursorX();
            let y = InputCursorY();
            return (x, y);
        }
    }
}

#[derive(Clone, Copy)]
pub struct Color {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
}

mod engine {
    #[link(wasm_import_module = "env")]
    extern "C" {
        fn EngineLog(ptr: *const u8, len: usize);
        fn EngineFps() -> f32;
        fn EngineTps() -> f32;
        fn EngineExit();
        fn EngineRandomFloat() -> f32;
        fn EngineRandomInt(max: i32) -> i32;
    }

    pub fn log(s: &str) {
        unsafe { EngineLog(s.as_ptr(), s.len()) }
    }
    pub fn random_float() -> f32 {
        unsafe { EngineRandomFloat() }
    }
    pub fn random_int(max: i32) -> i32 {
        unsafe { EngineRandomInt(max) }
    }
    pub fn fps() -> f32 {
        unsafe { EngineFps() }
    }
    pub fn tps() -> f32 {
        unsafe { EngineTps() }
    }
    pub fn exit() {
        unsafe { EngineExit() }
    }
}

mod gfx {
    #[link(wasm_import_module = "env")]
    extern "C" {
        fn GfxClear(r: f32, g: f32, b: f32, a: f32);
        fn GfxText(ptr: *const u8, len: usize, x: f32, y: f32);
        fn GfxRectangle(x: f32, y: f32, w: f32, h: f32, cr: f32, cg: f32, cb: f32, ca: f32);
        fn GfxImage(x: f32, y: f32, or: f32, og: f32, ob: f32, oa: f32);
    }

    pub fn clear(color: crate::Color) {
        unsafe {
            GfxClear(color.r, color.g, color.b, color.a);
        }
    }

    pub fn image(x: f32, y: f32, c: crate::Color) {
        unsafe {
            GfxImage(x, y, c.r, c.g, c.b, c.a);
        }
    }

    pub fn rectangle(x: f32, y: f32, w: f32, h: f32, c: crate::Color) {
        unsafe {
            GfxRectangle(x, y, w, h, c.r, c.g, c.b, c.a);
        }
    }

    pub fn text(s: &str, x: f32, y: f32) {
        unsafe {
            GfxText(s.as_ptr(), s.len(), x, y);
        }
    }
}
pub struct Vector {
    pub x: f32,
    pub y: f32,
}
pub struct Gopher {
    pub pos: Vector,
    pub vel: Vector,
    pub color: Color,
}

static GRAVITY: f32 = 0.0981;
static STARTING_GOPHERS: usize = 1000;
static GOPHERS_PER_CLICK: usize = 1000;
static SPRITE_W: f32 = 27.0;
static SPRITE_H: f32 = 29.0;
static mut GOPHERS: std::vec::Vec<Gopher> = std::vec::Vec::new();

static COLORS: [Color; 3] = [
    Color {
        r: 1.0,
        g: 0.25,
        b: 0.25,
        a: 0.75,
    },
    Color {
        r: 0.25,
        g: 1.0,
        b: 0.25,
        a: 0.6,
    },
    Color {
        r: 0.25,
        g: 0.25,
        b: 1.0,
        a: 0.65,
    },
];

#[no_mangle]
pub extern "C" fn setup() {
    engine::log("Setup");

    for _ in 0..STARTING_GOPHERS {
        unsafe {
            GOPHERS.push(Gopher {
                pos: Vector { x: 0.0, y: 0.0 },
                vel: Vector {
                    x: engine::random_float() * 5.0,
                    y: engine::random_float() * 5.0,
                },
                color: COLORS[engine::random_int(COLORS.len() as i32) as usize],
            });
        }
    }
}

#[no_mangle]
pub extern "C" fn teardown() {
    engine::log("Teardown");
}

#[no_mangle]
pub extern "C" fn frame() {
    if input::pressed(1) {
        engine::exit();
    }

    if input::pressed(2) {
        let (mx, my) = input::cursor_position();
        unsafe {
            let mut to_add: Vec<Gopher> = Vec::with_capacity(GOPHERS_PER_CLICK);
            for _ in 0..GOPHERS_PER_CLICK {
                to_add.push(Gopher {
                    color: COLORS[engine::random_int(COLORS.len() as i32) as usize],
                    pos: Vector { x: mx, y: my },
                    vel: Vector {
                        x: engine::random_float() * 5.0,
                        y: engine::random_float() * 5.0,
                    },
                });
            }

            GOPHERS.extend(to_add);
        }
    }

    gfx::clear(Color {
        r: 0.19,
        g: 0.19,
        b: 0.19,
        a: 1.0,
    });

    const SW: f32 = 640.0;
    const SH: f32 = 480.0;

    unsafe {
        for g in GOPHERS.iter_mut() {
            g.vel.y += GRAVITY;
            g.pos.x += g.vel.x;
            g.pos.y += g.vel.y;

            if g.pos.y >= SH - SPRITE_H {
                g.vel.y *= 0.85 / 2.0;
                if engine::random_float() > 0.5 {
                    g.vel.y -= engine::random_float() * 8.0;
                }
            } else if g.pos.y < 0.0 {
                g.vel.y = -g.vel.y;
            }

            if g.pos.x > SW - SPRITE_W {
                g.vel.x = -g.vel.x.abs();
            } else if g.pos.x < 0.0 {
                g.vel.x = g.vel.x.abs();
            }

            gfx::image(g.pos.x, g.pos.y, g.color);
        }
    }

    let fps = format!("fps: {}", engine::fps());
    let tps = format!("tps: {}", engine::tps());
    let gophers = format!("gophers: {}", unsafe { GOPHERS.len() });

    gfx::rectangle(
        10.0,
        10.0,
        125.0,
        55.0,
        Color {
            r: 0.0,
            g: 0.0,
            b: 0.0,
            a: 0.5,
        },
    );

    gfx::text("lang: rust", 10.0, 10.0);
    gfx::text(fps.as_str(), 10.0, 24.0);
    gfx::text(tps.as_str(), 10.0, 36.0);
    gfx::text(gophers.as_str(), 10.0, 48.0);
}
