#!/usr/bin/env sh

tinygo build -o game.wasm -target=wasm -opt=2 -no-debug -panic=trap -scheduler=none . &&\
mv game.wasm ../
