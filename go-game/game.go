package main

import (
	"math"
	"strconv"
)

type (
	Color struct {
		R, G, B, A float32
	}
	Vec2 struct {
		X, Y float32
	}
)

type Gopher struct {
	pos Vec2
	vel Vec2
	col Color
}

const (
	gravity         = 0.0981
	startingGophers = 1000
	gophersPerClick = 1000
	screenWidth     = 640
	screenHeight    = 480
	spriteWidth     = 27
	spriteHeight    = 29
)

var (
	gophers = make([]Gopher, startingGophers)
	colors  = []Color{
		{R: 1, G: 0.25, B: 0.25, A: 0.75},
		{R: 0.25, G: 1, B: 0.25, A: 0.60},
		{R: 0.25, G: 0.25, B: 1, A: 0.65},
	}
)

//go:export setup
func Setup() {
	EngineLog("Setup")

	for i := range gophers {
		g := &gophers[i]
		g.vel = Vec2{X: EngineRandomFloat() * 5, Y: EngineRandomFloat() * 5}
		g.col = colors[EngineRandomInt(int32(len(colors)))]
	}
}

//go:export teardown
func Teardown() {
	EngineLog("Teardown")
}

//go:export frame
func Frame() {
	if InputPressed(1) {
		EngineExit()
		return
	}

	if InputPressed(2) {
		mx, my := inputCursorPosition()
		toAdd := [gophersPerClick]Gopher{}
		for i := range toAdd {
			g := &toAdd[i]
			g.pos = Vec2{X: mx, Y: my}
			g.vel = Vec2{X: EngineRandomFloat() * 5, Y: EngineRandomFloat() * 5}
			g.col = colors[EngineRandomInt(int32(len(colors)))]
		}

		gophers = append(gophers, toAdd[:]...)
	}

	gfxClear(Color{R: .19, G: .19, B: .19, A: 1})

	for i := range gophers {
		g := &gophers[i]
		g.vel.Y += gravity
		g.pos.X += g.vel.X
		g.pos.Y += g.vel.Y

		if g.pos.Y >= screenHeight-spriteHeight {
			g.vel.Y *= 0.85 / 2
			if EngineRandomFloat() > 0.5 {
				g.vel.Y -= EngineRandomFloat() * 8
			}
		} else if g.pos.Y < 0 {
			g.vel.Y = -g.vel.Y
		}

		if g.pos.X >= screenWidth-spriteWidth {
			g.vel.X = -float32(math.Abs(float64(g.vel.X)))
		} else if g.pos.X < 0 {
			g.vel.X = float32(math.Abs(float64(g.vel.X)))
		}

		gfxImage(g.pos.X, g.pos.Y, g.col)
	}

	var (
		fps = EngineFps()
		tps = EngineTps()
	)

	gfxRectangle(10, 10, 125, 55, Color{R: 0, G: 0, B: 0, A: 0.5})

	GfxText("lang: go", 10, 10)
	GfxText("fps: "+strconv.FormatFloat(float64(fps), 'f', 2, 32), 10, 24)
	GfxText("tps: "+strconv.FormatFloat(float64(tps), 'f', 2, 32), 10, 36)
	GfxText("gophers: "+strconv.Itoa(len(gophers)), 10, 48)
}

func main() {}

//go:export EngineLog
func EngineLog(s string)

//go:export EngineExit
func EngineExit()

//go:export EngineFps
func EngineFps() float32

//go:export EngineTps
func EngineTps() float32

//go:export EngineRandomInt
func EngineRandomInt(int32) int32

//go:export EngineRandomFloat
func EngineRandomFloat() float32

//go:export InputPressed
func InputPressed(int32) bool

//go:export InputCursorX
func InputCursorX() float32

//go:export InputCursorY
func InputCursorY() float32

func inputCursorPosition() (float32, float32) {
	x := InputCursorX()
	y := InputCursorY()
	return x, y
}

//go:export GfxClear
func GfxClear(r, g, b, a float32)

func gfxClear(c Color) {
	GfxClear(c.R, c.G, c.B, c.A)
}

//go:export GfxImage
func GfxImage(x, y float32, or, og, ob, oa float32)

func gfxImage(x, y float32, c Color) {
	GfxImage(x, y, c.R, c.G, c.B, c.A)
}

//go:export GfxText
func GfxText(str string, x, y float32)

//go:export GfxRectangle
func GfxRectangle(x, y, w, h float32, or, og, ob, oa float32)

func gfxRectangle(x, y, w, h float32, c Color) {
	GfxRectangle(x, y, w, h, c.R, c.G, c.B, c.A)
}
