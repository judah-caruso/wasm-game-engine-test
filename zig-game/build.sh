#!/usr/bin/env sh

zig build &&\
mv zig-out/lib/game.wasm ../
