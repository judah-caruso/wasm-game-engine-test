# Wasm Game Engine Test

This repository was created to see how feasible it is to use [wazero](https://wazero.io/) to drive a small game engine (using [Ebitengine](https://ebitengine.org/)). It simply sets up Ebitengine and exports a small api for wasm to import.

If you're trying to do something similar, hopefully this provides a decent starting point.

![](screenshot.png)

## Installation

- Install the toolchain for the language you want to compile (zig, rust, odin, tinygo, assemblyscript)
- `cd` into their `[lang]-game` directory
- run `./build.sh` (this will create a `game.wasm` file in the root directory)
- run `go run .` in the root directory to start the game

## Some minor benchmarks

Below are a few grain-of-salt metrics I've gathered for each bunnymark-styled demo. This **isn't** intended to be a direct comparison of performance, more to see how much overhead there is when calling between wazero/wasm and go.

Note: these were ran on a 2022 M2 MacBook Air (8GB)

```
Language  60 Fps Max  60 Tps Max (Avg. Fps)
asc           22,000      71,000 (14)
odin          23,000      88,000 (15)
zig           24,000      83,000 (15)
go            25,000      94,000 (15)
rust          25,000      94,000 (15)
```

Below compares this approach to other ways I've tested:

```
Runtime        60 Fps Max  60 Tps Max (Avg. Fps)
go/goja             2,000       3,000 (18)
go/gopher-lua      13,000      22,000 (19)
go/browser[1]      13,000      49,000 (14)
go/wazero[2]       53,000     184,000 (15)
go/native[3]       55,000     192,000 (15)
go/native[4]       64,000     230,000 (14)
```

- 60 Fps Max: number of entities before consistent fps is below 60
- 60 Tps Max: number of entities before consistent tps is below 60
- Avg. Fps: average fps when tps is passed tps max

1. [Ebitengine Sprites Example](https://ebitengine.org/en/examples/sprites.html)
2. BrutEngine (my custom wasm engine)
3. [Ebitengine Bunnymark](https://github.com/sedyh/ebitengine-bunny-mark)
4. [Gophermark](https://github.com/judah-caruso/gophermark)

From my tests, embedding wasm/wazero within a native go application
performs better than embedding lua/js or running wasm in the browser.
However, as expected, both still perform significantly worse than native compilation.

Keep in mind that "bunnymark" isn't a definitive benchmark and your mileage may vary.

## License

Public Domain
