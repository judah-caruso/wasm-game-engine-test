#!/usr/bin/env sh

odin build . --target:freestanding_wasm32 -out:game.wasm -no-entry-point -extra-linker-flags:"--lto-O3 --gc-sections" &&\
mv game.wasm ../
