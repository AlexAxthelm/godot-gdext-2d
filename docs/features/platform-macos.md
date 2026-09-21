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
- Open `godot/` in the editor to play. (Godot run/smoke `make` targets arrive in
  Phase 2 once a main scene exists.)

## Notes
- Universal (arm64 + x86_64) packaging is a later concern; development is arm64.
- macOS proves the whole Rust↔Godot loop before the harder platforms.

## Status
Phase 2 (see `ROADMAP.md`).
