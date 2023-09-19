const startingGophers = 1000;
const gophersPerClick = 1000;

const gravity: f32 = 0.0981;
const spriteW: f32 = 27.0;
const spriteH: f32 = 29.0;
const screenW: f32 = 640.0;
const screenH: f32 = 480.0;

let gophers = new Array<Gopher>(startingGophers);

class Gopher {
  pos: Vec = { x: 0, y: 0 };
  vel: Vec = { x: 0, y: 0 };
  color: Color = { r: 1, g: 1, b: 1, a: 1 };
};

class Vec {
  x: f32 = 0;
  y: f32 = 0;
}

class Color {
  r: f32 = 0;
  g: f32 = 0;
  b: f32 = 0;
  a: f32 = 1;
};

const colors: Color[] = [
  { r: 1, g: 0.25, b: 0.25, a: 0.75 },
  { r: 0.25, g: 1, b: 0.25, a: 0.60 },
  { r: 0.25, g: 0.25, b: 1, a: 0.65 },
];

export function setup(): void {
  engineLog("setup");

  for (let i = 0; i < startingGophers; i += 1) {
    gophers[i] = {
      pos: { x: 0, y: 0 },
      vel: { x: engineRandomFloat() * 5, y: engineRandomFloat() * 5 },
      color: colors[engineRandomInt(colors.length)]
    };
  }
};

export function teardown(): void {
  engineLog("teardown");
};

export function update(): void {
  if (inputPressed(1)) {
    engineExit();
    return;
  }

  if (inputPressed(2)) {
    const mx = inputCursorX();
    const my = inputCursorY();

    for (let i = 0; i < gophersPerClick; i += 1) {
      gophers.push({
        pos: { x: mx, y: my },
        vel: { x: engineRandomFloat() * 5, y: engineRandomFloat() * 5 },
        color: colors[engineRandomInt(colors.length)]
      });
    }
  }

  for (let i = 0; i < gophers.length; i += 1) {
    const g = gophers[i];
    g.vel.y += gravity;
    g.pos.x += g.vel.x;
    g.pos.y += g.vel.y;

    if (g.pos.y >= screenH - spriteH) {
      g.vel.y *= 0.85 / 2;
      if (engineRandomFloat() > 0.5) {
        g.vel.y -= engineRandomFloat() * 8;
      }
    } else if (g.pos.y < 0) {
      g.vel.y = -g.vel.y;
    }

    if (g.pos.x >= screenW - spriteW) {
      g.vel.x = -f32(Math.abs(g.vel.x));
    } else if (g.pos.x < 0) {
      g.vel.x = f32(Math.abs(g.vel.x));
    }
  }
};

export function render(): void {
  gfxClear({ r: 0.19, g: 0.19, b: 0.19, a: 1 });

  for (let i = 0; i < gophers.length; i += 1) {
    const g = gophers[i];
    gfxImage(g.pos.x, g.pos.y, g.color);
  }

  gfxRectangle(10, 10, 125, 55, { r: 0, g: 0, b: 0, a: 0.5 });

  const fps = engineFps();
  const tps = engineTps();

  gfxText("lang: asc", 10, 10);
  gfxText(`fps: ${Math.round(fps * 100) / 100}`, 10, 24);
  gfxText(`tps: ${Math.round(tps * 100) / 100}`, 10, 36);
  gfxText(`gophers: ${gophers.length}`, 10, 48);
};

@inline const engineLog = (s: string): void => {
  const utf8 = String.UTF8.encode(s);
  const ptr = changetype<u32>(utf8);
  EngineLog(ptr, u32(utf8.byteLength));
};

@inline const gfxClear = (c: Color): void => GfxClear(c.r, c.g, c.b, c.a);

@inline const gfxImage = (x: f32, y: f32, c: Color): void => GfxImage(x, y, c.r, c.g, c.b, c.a);

@inline const gfxText = (s: string, x: f32, y: f32): void => {
  const utf8 = String.UTF8.encode(s);
  const ptr = changetype<u32>(utf8);
  GfxText(ptr, u32(utf8.byteLength), x, y);
}

@inline const gfxRectangle = (x: f32, y: f32, w: f32, h: f32, c: Color): void => {
  GfxRectangle(x, y, w, h, c.r, c.g, c.b, c.a);
}

@external("env", "EngineLog")
declare function EngineLog(s: u32, l: u32): void;

@external("env", "EngineFps")
declare function engineFps(): f32;

@external("env", "EngineTps")
declare function engineTps(): f32;

@external("env", "EngineRandomFloat")
declare function engineRandomFloat(): f32;

@external("env", "EngineRandomInt")
declare function engineRandomInt(max: i32): i32;

@external("env", "EngineExit")
declare function engineExit(): void;

@external("env", "GfxClear")
declare function GfxClear(r: f32, g: f32, b: f32, a: f32): void;

@external("env", "GfxImage")
declare function GfxImage(x: f32, y: f32, r: f32, g: f32, b: f32, a: f32): void;

@external("env", "GfxRectangle")
declare function GfxRectangle(x: f32, y: f32, w: f32, h: f32, r: f32, g: f32, b: f32, a: f32): void;

@external("env", "GfxText")
declare function GfxText(s: u32, l: u32, x: f32, y: f32): void;

@external("env", "InputPressed")
declare function inputPressed(input: i32): bool;

@external("env", "InputCursorX")
declare function inputCursorX(): f32;

@external("env", "InputCursorY")
declare function inputCursorY(): f32;

const seedHandler = (): f64 => {
  return 0;
}
