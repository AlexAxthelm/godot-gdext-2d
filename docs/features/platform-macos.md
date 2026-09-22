# Platform: macOS
---
priority: MVP
depends: gameplay-hotseat
---

macOS is the primary and first target — it runs straight from the Godot editor
against the debug `libtictactoe.dylib`, with no extra toolchain beyond Rust
stable and Godot 4.7.1.

## Build & run
- `make rust-build` produces `rust/target/debug/libtictactoe.dylib`.
- `godot/tictactoe.gdextension` maps `macos.debug`/`macos.release` to it.
- `make run` builds the dylib and launches the project (`godot --path godot`).
- Open `godot/` in the editor to play, or `make smoke` for the headless test.

## Notes
- Universal (arm64 + x86_64) packaging is a later concern; development is arm64.
- macOS proves the whole Rust↔Godot loop before the harder platforms.

## Status
Phase 2 (done): playable from the editor and via `make run`. See `ROADMAP.md`.
