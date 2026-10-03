# Architecture
---
Read this before diving into the code. This is a living document.
It is the technical companion to `DESIGN_PRINCIPLES.md` (philosophy) and
`ROADMAP.md` (implementation order).
---

## Overview

A cross-platform tic-tac-toe game. **Rust owns the game logic; Godot owns
rendering and I/O.** The game itself is deliberately trivial — the real
deliverable is a clean, reusable skeleton and a proven multi-platform build
pipeline that a more complex game can grow into.

## Repository layout

```
.
├── Makefile                  # per-platform build/run/export orchestration
├── rust/                     # Cargo workspace
│   ├── Cargo.toml            # [workspace] members = core, godot
│   ├── rust-toolchain.toml   # stable
│   ├── core/                 # PURE game logic — no godot dependency, unit-tested
│   └── godot/                # thin gdext binding (cdylib + staticlib)
├── godot/                    # the Godot project (open this in the editor)
│   ├── project.godot
│   ├── tictactoe.gdextension # platform → compiled-library map
│   └── .godot/extension_list.cfg   # committed so a fresh clone loads the extension
└── docs/                     # this documentation set (see below)
```

## The two-crate split

The single most important structural decision: **`tictactoe-core` has no Godot
dependency.**

| Crate             | Role                                            | Depends on   |
| ----------------- | ----------------------------------------------- | ------------ |
| `tictactoe-core`  | All game rules. Pure Rust. `cargo test`-able.   | *(nothing)*  |
| `tictactoe-godot` | Thin translation layer to the engine.           | godot, core  |

`tictactoe-godot` produces `crate-type = ["cdylib", "staticlib"]`: `cdylib` for
desktop/web, `staticlib` (`.a`) for iOS. It hosts the `#[gdextension]` entry
point and (Phase 2+) a root `TicTacToe` node that translates Godot input/UI
events into `core` calls and emits signals back to the scene. **Game rules never
live in the binding crate.**

## Rust ↔ Godot boundary

```
   Godot scene (main.tscn)          tictactoe-godot            tictactoe-core
   ┌──────────────────────┐         ┌───────────────┐          ┌────────────┐
   │ 3x3 grid of buttons  │ pressed │  TicTacToe    │  play()  │  Board /   │
   │ status label         │────────▶│  (Node)       │─────────▶│  GameState │
   │ reset button         │◀────────│               │◀─────────│  (rules)   │
   └──────────────────────┘ signals └───────────────┘  result  └────────────┘
```

Input is abstracted through Godot's **InputMap actions** (`cursor_*`, `place`,
`reset`) so mouse, touch, keyboard, and gamepad all produce the same core
commands. See `DESIGN_PRINCIPLES.md`.

## Toolchain

- **Rust** stable (`rust/rust-toolchain.toml`); Web build overrides to nightly
  for `-Zbuild-std`.
- **Godot 4.7.1**. gdext is pinned via git in the committed `Cargo.lock`
  (crates.io releases lag the 4.7 API).
- Per-platform toolchain notes live in `HACKING.md`.

## Target platforms

Shipping targets: **macOS, iOS, Windows, Web (WASM)**, then **Android** and
**Linux**. **Consoles are an explicit non-target** — Godot has no first-party
console export; shipping there requires a commercial porting partner under NDA.

## CI

GitHub Actions (`.github/workflows/ci.yml`): a `rust` job (check/clippy/test on
stable) is the always-on gate; `godot` (headless smoke) and `wasm` jobs come
online with their phases.

## Current state

**Phase 2 complete: first playable build.** A playable two-player hot-seat game
runs in the editor and via `make run` on macOS. The `TicTacToe` node
(`rust/godot/src/node.rs`) owns a `core::Board` and emits `cell_changed` /
`turn_changed` / `game_over`; a thin, fully-typed `main.gd` view reacts to those
signals and holds no rules. A headless GdUnit4 smoke test (`make smoke`) covers
the loop. See `ROADMAP.md` for what lands next.

### The GDScript view & its safety net

The scene's `main.gd` is deliberately thin — it forwards input and repaints on
signals, nothing more. Because GDScript is not compiled like Rust, that seam is
guarded by: static typing with warnings-as-errors (`godot/project.godot`), a
`--check-only` parse gate (`make gd-check`), `gdlint`/`gdformat` via gdtoolkit,
and the GdUnit4 scene smoke test — which is the real net for broken node
references or renamed signals. Keeping the view thin keeps that surface small.
