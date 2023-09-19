package game

import "core:runtime"
import "core:mem"
import "core:math"
import "core:strings"
import "core:math/linalg"
import "core:intrinsics"
import "vendor:wasm"

foreign import env "env"

@(default_calling_convention = "c")
foreign env {
	EngineLog         :: proc(str: u32, len: u32) ---
	EngineFps         :: proc() -> f32 ---
	EngineTps         :: proc() -> f32 ---
	EngineRandomInt   :: proc(max: i32) -> i32 ---
	EngineRandomFloat :: proc() -> f32 ---
	EngineExit        :: proc() ---

	GfxClear     :: proc(r: f32, g: f32, b: f32, a: f32) ---
	GfxImage     :: proc(x: f32, y: f32, r: f32, g: f32, b: f32, a: f32) ---
	GfxRectangle :: proc(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32) ---
	GfxText      :: proc(str: u32, len: u32, x: f32, y: f32) ---

	InputPressed :: proc(input: i32) -> bool ---
	InputCursorX :: proc() -> f32 ---
	InputCursorY :: proc() -> f32 ---
}

engine_log :: #force_inline proc(s: string) {
	ptr, count := to_raw_string(s)
	EngineLog(ptr, count)
}
engine_random_int :: proc(max: i32) -> i32 {
	return EngineRandomInt(max)
}
engine_random_float :: proc() -> f32 {
	return EngineRandomFloat()
}
engine_fps :: proc() -> f32 {
	return EngineFps()
}
engine_tps :: proc() -> f32 {
	return EngineTps()
}
engine_exit :: proc() {
	EngineExit()
}

gfx_clear :: proc(c: Color) {
	GfxClear(c.r, c.g, c.b, c.a)
}
gfx_text :: #force_inline proc(s: string, x, y: f32) {
	ptr, count := to_raw_string(s)
	GfxText(ptr, count, x, y)
}
gfx_rectangle :: proc(x, y, w, h: f32, c: Color) {
	GfxRectangle(x, y, w, h, c.r, c.g, c.b, c.a)
}
gfx_image :: proc(x, y: f32, c: Color) {
	GfxImage(x, y, c.r, c.g, c.b, c.a)
}

input_pressed :: proc(input: i32) -> bool {
	return InputPressed(input)
}
input_cursor_position :: proc() -> (f32, f32) {
	x := InputCursorX()
	y := InputCursorY()
	return x, y
}

to_raw_string :: #force_inline proc (s: string) -> (u32, u32) {
	s := s
	rs := (cast(^runtime.Raw_String)&s)
	return u32(uintptr(rs.data)), u32(rs.len)
}


Gopher :: struct {
	vel:   linalg.Vector2f32,
	pos:   linalg.Vector2f32,
	color: Color,
}

Color :: struct {
	r, g, b, a: f32,
}

GRAVITY :: 0.0981
STARTING_GOPHERS :: 1000
GOPHERS_PER_CLICK :: 1000

SPRITE_W :: 27
SPRITE_H :: 29

main_data: []byte
main_arena: Arena
main_alloc: mem.Allocator

// @todo(judah): can't get temp allocators to work, so opting for a simple string buffer
string_backing: []byte

gophers: [dynamic]Gopher
colors := [?]Color{
	{ r = 1, g = 0.25, b = 0.25, a = 0.75 },
	{ r = 0.25, g = 1, b = 0.25, a = 0.60 },
	{ r = 0.25, g = 0.25, b = 1, a = 0.65 },
}

wasm_ctx := runtime.default_context()

@(export)
setup :: proc "contextless" () {
	context = wasm_ctx

	// ensure no hidden allocations happen during setup
	context.allocator      = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()

	engine_log("Setup")

	err: mem.Allocator_Error

	main_data, err = page_alloc(128)
	if err != .None {
		engine_log("allocation main pages failed!")
		engine_exit()
	}

	arena_init(&main_arena, main_data[:])
	main_alloc = arena_allocator(&main_arena)

	// allocations can happen from this point on
	context.allocator = main_alloc

   gophers = make([dynamic]Gopher, STARTING_GOPHERS)
   for i in 0..<STARTING_GOPHERS {
      append(&gophers, Gopher{
         pos = { 0, 0 },
         vel = { engine_random_float() * 5, engine_random_float() * 5 },
			color = colors[engine_random_int(len(colors))],
      })
   }

	string_backing = make([]byte, 1024)
}

@(export)
teardown :: proc "contextless" () {
	context = wasm_ctx
	engine_log("Teardown")
}

@(export)
update :: proc "contextless" () {
	context = wasm_ctx
	// defer free_all(context.temp_allocator)

	sw :: 640
	sh :: 480

	if input_pressed(1) {
		engine_exit()
		return
	}

	if input_pressed(2) {
		mx, my := input_cursor_position()

		for _ in 0..<GOPHERS_PER_CLICK {
			append(&gophers, Gopher{
				pos = { mx, my },
				vel = { engine_random_float() * 5, engine_random_float() * 5 },
				color = colors[engine_random_int(len(colors))],
			})
		}
	}

   for g in &gophers {
		g.vel.y += GRAVITY
		g.pos += g.vel

		if g.pos.y >= sh - SPRITE_H {
			g.vel.y *= 0.85 / 2
			if engine_random_float() > 0.5 {
				g.vel.y -= engine_random_float() * 8
			}
		} else if g.pos.y < 0 {
			g.vel.y = -g.vel.y
		}

		if g.pos.x > sw - SPRITE_W {
			g.vel.x = -math.abs(g.vel.x)
		} else if g.pos.x < 0 {
			g.vel.x = math.abs(g.vel.x)
		}
   }
}

@(export)
render :: proc "contextless" () {
	context = wasm_ctx

	gfx_clear({.19, .19, .19, 1})

	for g in gophers {
      gfx_image(g.pos.x, g.pos.y, g.color)
	}

	gfx_rectangle(10, 10, 125, 55, { 0, 0, 0, 0.5 })
	gfx_text("lang: odin", 10, 10)

	// @todo(judah): can't get the temp allocator to work with fmt.tprintf

	buf := strings.builder_from_slice(string_backing[:])
	strings.write_string(&buf, "fps: ")
	strings.write_float(&buf, f64(engine_fps()), 'f', 2, 32)
	gfx_text(strings.to_string(buf), 10, 24)
	strings.builder_reset(&buf)

	strings.write_string(&buf, "tps: ")
	strings.write_float(&buf, f64(engine_tps()), 'f', 2, 32)
	gfx_text(strings.to_string(buf), 10, 36)
	strings.builder_reset(&buf)

	strings.write_string(&buf, "gophers: ")
	strings.write_int(&buf, len(gophers))
	gfx_text(strings.to_string(buf), 10, 48)
	strings.builder_reset(&buf)
}
