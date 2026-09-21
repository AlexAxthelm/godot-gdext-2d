# Hacking
---
Local setup, the build commands, and per-platform toolchain notes. This is a
living document — add gotchas as you hit them.
---

## Prerequisites

- **Rust** (stable) via rustup. The workspace pins `channel = "stable"` in
  `rust/rust-toolchain.toml`.
- **Godot 4.7.1** on `PATH` as `godot`.

## Everyday loop

All commands run from the repo root via `make`. Aggregate targets fan out to the
granular `rust-*` targets, and each granular target maps 1:1 to a CI check.

```sh
make check         # all Rust gates: check + test + lint + fmt + lockfile
make test          # pure-core unit tests, no engine
make lint          # clippy -D warnings
make format        # apply rustfmt   (format-check verifies without writing)
make rust-build    # debug build of the Rust workspace
make clean         # remove Rust build artifacts
```

`make rust-build` produces `rust/target/debug/libtictactoe.dylib` (macOS), which
`godot/tictactoe.gdextension` points at. Build at least once before opening the
Godot editor so the extension has a library to load.

## Godot

The Godot project lives in `godot/`. For now, `make rust-build` then open `godot/`
in the Godot 4.7.1 editor (or `godot --path godot`) to load the extension. The
extension is registered via `godot/.godot/extension_list.cfg`, which **is
committed** so a fresh clone / CI loads it on first open.

Godot run/export `make` targets are added in Phase 2+ once a main scene exists
(see `ROADMAP.md`); the Makefile currently carries only the Rust targets above.

## Per-platform toolchain notes

### macOS (Phase 2) — primary target
Nothing beyond Rust stable + Godot. Debug build runs straight from the editor.

### iOS (Phase 3)
- Xcode + the `aarch64-apple-ios` rustup target.
- No arm64 **simulator** slice in the Godot iOS template — run via Xcode's
  "My Mac (Designed for iPad)" (free Apple ID) or a physical device (paid
  Apple Developer account for signing).
- `make build-ios` then `make export-ios` (to be added in Phase 3).

### Web / WASM (Phase 4)
- **Rust nightly** + `rust-src` component + the `wasm32-unknown-emscripten` target.
- **Emscripten (emsdk)** installed and activated in the shell.
- `rust/godot/.cargo/config.toml` already carries the required SIDE_MODULE
  linker flags.
- `make build-wasm` uses `cargo +nightly ... -Zbuild-std --features nothreads`.

### Windows (Phase 5)
- Cross-compiling Godot+Rust from macOS is awkward; prefer a Windows machine or
  a CI runner. Local attempt: `x86_64-pc-windows-gnu` target + mingw.

### Android / Linux (later)
- Android: JDK + Android SDK/NDK + Godot Android export templates.
- Linux: desktop export from the editor / CI runner.

## Committing

Per project policy (`docs/policies/CONTRIBUTING.md`): Conventional Commits,
`make check` must pass before a PR. Do not commit `rust/target/` or the
generated `godot/.godot/` caches (the `.gitignore` handles this).
