#!/usr/bin/env sh

cargo build --target=wasm32-unknown-unknown --release &&\
mv target/wasm32-unknown-unknown/release/game.wasm ../
