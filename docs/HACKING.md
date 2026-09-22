# Hacking
---
Local setup, the build commands, and per-platform toolchain notes. This is a
living document — add gotchas as you hit them.
---

## Prerequisites

- **Rust** (stable) via rustup. The workspace pins `channel = "stable"` in
  `rust/rust-toolchain.toml`.
- **Godot 4.7.1** on `PATH` as `godot`.
- **gdtoolkit** for the GDScript gates: `pipx install gdtoolkit` (or
  `pip install --user gdtoolkit`, then put its scripts dir — e.g.
  `~/Library/Python/3.x/bin` — on `PATH`) so `gdlint`/`gdformat` resolve.
- **GdUnit4** (the GDScript test framework) is **not** vendored — `make smoke`
  fetches the pinned version into a gitignored `godot/addons/gdUnit4/` on first
  run (see `make gd-test-deps`).

## Everyday loop

All commands run from the repo root via `make`. Aggregate targets fan out to the
granular `rust-*` targets, and each granular target maps 1:1 to a CI check.

```sh
make check         # all gates, Rust + GDScript (check/test/lint/fmt/lock + gd-*)
make test          # pure-core unit tests, no engine
make lint          # clippy -D warnings + gdlint
make format        # apply rustfmt + gdformat  (format-check verifies only)
make rust-build    # debug build of the Rust workspace
make run           # build the dylib and launch the game (godot --path godot)
make smoke         # headless GdUnit4 scene smoke test (fetches GdUnit4 if needed)
make clean         # remove Rust build artifacts
```

The GDScript gates that `make check` adds: `gd-check` (`godot --check-only`,
honouring the warnings-as-errors in `project.godot`), `gd-lint`, and
`gd-format-check`. They run on our own scripts only — the fetched GdUnit4 addon is
excluded, and the `test/` suite is excluded from `gd-check` (it needs the
framework) but still linted/formatted. `make smoke` type-checks the tests by
running them.

`make rust-build` produces `rust/target/debug/libtictactoe.dylib` (macOS), which
`godot/tictactoe.gdextension` points at. Build at least once before opening the
Godot editor so the extension has a library to load.

## Godot

The Godot project lives in `godot/`. Use `make run` (which builds the dylib first)
to launch the game, or open `godot/` in the Godot 4.7.1 editor to play/edit. The
extension is registered via `godot/.godot/extension_list.cfg`, which **is
committed** so a fresh clone / CI loads it on first open.

Godot export `make` targets arrive with their platform phases (see `ROADMAP.md`);
CI's Godot-headless jobs (the `--check-only` gate and the smoke test) land with
Phase 5. Both run locally today via `make gd-check` and `make smoke`.

## Per-platform toolchain notes

### macOS (Phase 2, done) — primary target
Nothing beyond Rust stable + Godot. Debug build runs straight from the editor or
via `make run`.

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
