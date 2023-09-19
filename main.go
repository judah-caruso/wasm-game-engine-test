package main

import (
	"bytes"
	"context"
	_ "embed"
	"errors"
	"fmt"
	"image"
	"image/color"
	_ "image/png"
	"log"
	"math/rand"
	"os"
	"time"

	eb "github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"github.com/hajimehoshi/ebiten/v2/vector"
	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
)

var (
	G           Game
	gopherImage *eb.Image
)

//go:embed gopher.png
var gopherImageData []byte

type Game struct {
	wasmCtx context.Context
	wasmRt  wazero.Runtime
	wasmMod api.Module

	wasmFnSetup    api.Function
	wasmFnTeardown api.Function
	wasmFnFrame    api.Function
	wasmStack      []uint64

	setupRan   bool
	shouldQuit bool

	renderWidth, renderHeight int
	renderSource              *eb.Image

	opts eb.DrawImageOptions
}

func main() {
	G.Setup()
	defer G.Teardown()

	eb.SetWindowResizingMode(eb.WindowResizingModeEnabled)

	if err := eb.RunGame(&G); err != nil && err != errExit {
		log.Fatal(err)
	}
}

func (g *Game) Setup() {
	wasmSrc, err := os.ReadFile("game.wasm")
	if err != nil {
		log.Fatal(err)
	}

	g.wasmCtx = context.Background()
	g.wasmRt = wazero.NewRuntime(g.wasmCtx)

	// Importing wasi so things don't complain nearly as much
	wasi_snapshot_preview1.MustInstantiate(g.wasmCtx, g.wasmRt)

	_, err = g.wasmRt.NewHostModuleBuilder("env").
		NewFunctionBuilder().WithFunc(engineLog).Export("EngineLog").
		NewFunctionBuilder().WithFunc(engineFps).Export("EngineFps").
		NewFunctionBuilder().WithFunc(engineTps).Export("EngineTps").
		NewFunctionBuilder().WithFunc(engineExit).Export("EngineExit").
		NewFunctionBuilder().WithFunc(engineRandomInt).Export("EngineRandomInt").
		NewFunctionBuilder().WithFunc(engineRandomFloat).Export("EngineRandomFloat").
		NewFunctionBuilder().WithFunc(engineExit).Export("EngineExit").
		NewFunctionBuilder().WithFunc(gfxClear).Export("GfxClear").
		NewFunctionBuilder().WithFunc(gfxImage).Export("GfxImage").
		NewFunctionBuilder().WithFunc(gfxRectangle).Export("GfxRectangle").
		NewFunctionBuilder().WithFunc(gfxText).Export("GfxText").
		NewFunctionBuilder().WithFunc(inputCursorX).Export("InputCursorX").
		NewFunctionBuilder().WithFunc(inputCursorY).Export("InputCursorY").
		NewFunctionBuilder().WithFunc(inputPressed).Export("InputPressed").
		Instantiate(g.wasmCtx)

	if err != nil {
		log.Fatal(err)
	}

	mod, err := g.wasmRt.Instantiate(g.wasmCtx, wasmSrc)
	if err != nil {
		log.Fatal(err)
	}

	// Since we're calling between wasm and go a lot,
	// setup a consistent stack that's reset before each call
	// (doesn't need to be 16 uint64s)
	g.wasmStack = make([]uint64, 16)
	g.wasmFnSetup = mod.ExportedFunction("setup")
	g.wasmFnTeardown = mod.ExportedFunction("teardown")
	g.wasmFnFrame = mod.ExportedFunction("frame")

	g.renderWidth = 640
	g.renderHeight = 480
	g.renderSource = eb.NewImage(g.renderWidth, g.renderHeight)
	if g.renderSource == nil {
		log.Fatal("unable to create render source")
	}

	img, _, err := image.Decode(bytes.NewReader(gopherImageData))
	if err != nil {
		log.Fatal(err)
	}

	gopherImage = eb.NewImageFromImage(img)
}

func (g *Game) Teardown() {
	g.WasmTeardown()
	g.wasmRt.Close(g.wasmCtx)
}

var (
	start          = time.Now()
	framesRendered = 0 // used for average frame time

	errExit = errors.New("exit")
)

// Eibtengen methods

func (g *Game) Update() error {
	if g.shouldQuit {
		return errExit
	}

	if !g.setupRan {
		g.WasmSetup()
		g.setupRan = true
	}

	g.WasmFrame()
	return nil
}

func (g *Game) Draw(sc *eb.Image) {
	// As it is now, the render source will never be nil.
	// However, if we add hotswapping there's a chance
	// it will be for a frame or so. You'd also want to
	// update all Gfx* procs to account for this.
	if g.renderSource != nil {
		op := eb.DrawImageOptions{}
		sc.DrawImage(g.renderSource, &op)
	}

	framesRendered += 1
	if framesRendered == 5 {
		avg := time.Since(start).Seconds() / float64(framesRendered)
		eb.SetWindowTitle(fmt.Sprintf("Wasm Game Engine Test - Avg Render Time: %.4f", avg))
		framesRendered = 0
		start = time.Now()
	}
}

func (g *Game) Layout(ww, wh int) (ow int, oh int) {
	return g.renderWidth, g.renderHeight
}

// Simple wrappers to call into wasm.

func (g *Game) WasmSetup() {
	if g.wasmFnSetup == nil {
		return
	}

	clear(g.wasmStack)
	err := g.wasmFnSetup.CallWithStack(g.wasmCtx, g.wasmStack)
	if err != nil {
		log.Println(err)
	}
}

func (g *Game) WasmTeardown() {
	if g.wasmFnTeardown == nil {
		return
	}

	clear(g.wasmStack)
	err := g.wasmFnTeardown.CallWithStack(g.wasmCtx, g.wasmStack)
	if err != nil {
		log.Println(err)
	}
}

func (g *Game) WasmFrame() {
	if g.wasmFnFrame == nil {
		return
	}

	clear(g.wasmStack)
	err := g.wasmFnFrame.CallWithStack(g.wasmCtx, g.wasmStack)
	if err != nil {
		log.Println(err)
	}
}

// Exported api

func engineLog(_ context.Context, m api.Module, offset, len uint32) {
	buf, ok := m.Memory().Read(offset, len)
	if !ok {
		log.Fatalf("Invalid memory read %d, %d", offset, len)
	}

	fmt.Println(string(buf))
}

func engineRandomFloat() float32 {
	return rand.Float32()
}

func engineRandomInt(max int32) int32 {
	return int32(rand.Intn(int(max)))
}

func engineFps() float32 {
	return float32(eb.ActualFPS())
}

func engineTps() float32 {
	return float32(eb.ActualTPS())
}

func inputPressed(i int32) int32 {
	pressed := false
	switch i {
	case 1:
		pressed = inpututil.IsKeyJustPressed(eb.KeyEscape)
	case 2:
		pressed = inpututil.IsMouseButtonJustPressed(eb.MouseButtonLeft)
	}

	if pressed {
		return 1
	}

	return 0
}

func inputCursorX() float32 {
	x, _ := eb.CursorPosition()
	return float32(x)
}

func inputCursorY() float32 {
	_, y := eb.CursorPosition()
	return float32(y)
}

func engineExit() {
	G.shouldQuit = true
}

func gfxClear(r, g, b, a float32) {
	G.renderSource.Fill(makeColor(r, g, b, a))
}

func gfxText(_ context.Context, m api.Module, offset, len uint32, x, y float32) {
	buf, ok := m.Memory().Read(offset, len)
	if !ok {
		log.Fatalf("Invalid memory read %d, %d", offset, len)
	}

	ebitenutil.DebugPrintAt(G.renderSource, string(buf), int(x), int(y))
}

func gfxImage(x, y float32, or, og, ob, oa float32) {
	G.opts.ColorScale.Reset()
	G.opts.ColorScale.ScaleWithColor(makeColor(or, og, ob, oa))

	G.opts.GeoM.Reset()
	G.opts.GeoM.Translate(float64(x), float64(y))
	G.renderSource.DrawImage(gopherImage, &G.opts)
}

func gfxRectangle(x, y, w, h float32, r, g, b, a float32) {
	vector.DrawFilledRect(
		G.renderSource,
		x, y,
		w, h,
		makeColor(r, g, b, a),
		false,
	)
}

func makeColor(r, g, b, a float32) color.RGBA {
	return color.RGBA{
		R: uint8(r * 255),
		G: uint8(g * 255),
		B: uint8(b * 255),
		A: uint8(a * 255),
	}
}
