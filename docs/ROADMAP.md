# Implementation Plan
---
A phased ordering from empty skeleton to a polished, multi-platform game. Each
phase closes with a `Milestone:` line describing the demonstrable outcome.
Phases are tackled one-per-branch. This is a living document.
---

## Phase 0 — Skeleton & docs  *(done)*
The reusable project shell, no gameplay.
- Cargo workspace (`core` + `godot`), `rust-toolchain.toml`, committed `Cargo.lock`.
- `core` type skeleton (`Player`, `Cell`, `Board`, `GameState`) + passing tests.
- `godot` binding stub: `#[gdextension]` entry point, wasm linker flags recorded.
- `Makefile`, `.gitignore`, Godot project scaffolding (`project.godot`,
  `tictactoe.gdextension`, committed `extension_list.cfg`, icon), CI `rust` job.
- This `docs/` set.

Milestone: `make check` and `make test` pass; opening `godot/` in Godot 4.7.1
registers the extension without error.

---
## Phase 1 — Pure core rules  *(done)*
The complete, engine-free game.
- `Board::try_play(idx)` with turn enforcement and illegal-move rejection
  (`MoveError::{OutOfBounds, CellOccupied, GameOver}`).
- Bounds-safe `Board::get(idx) -> Option<Cell>` so engine/UI indices never reach
  the panicking `cell()` (Phase 0 review finding).
- `winner() -> Option<(Player, [usize; 3])>`, `is_draw()`, `Board::state()`
  computing `GameState` (turn derived from cell parity, not stored).
- Exhaustive unit tests: all 8 win lines, draws, illegal moves, alternation.

Milestone: `make test` covers the full rules; zero Godot dependency in `core`.

---
## Phase 2 — Godot binding & scene (macOS)  *(done)*
First playable build.
- `TicTacToe` node holding a `core::Board`; `cell_changed` / `turn_changed` /
  `game_over` signals carrying tokens plus the winning line.
- `main.tscn`: 3x3 button grid + status label + reset button, driven by a thin,
  fully-typed `main.gd` view that holds no rules.
- InputMap actions (`cursor_up/down/left/right`, `place`, `reset`); keyboard +
  gamepad grid navigation alongside mouse/touch, handled in `_input` ahead of the
  built-in `ui_*` navigation.
- GDScript safety: static typing + warnings-as-errors + a `--check-only` parse
  gate, `gdlint`/`gdformat` (gdtoolkit), and a headless GdUnit4 scene smoke test
  (`make smoke`). CI wires the Godot-headless jobs in Phase 5; the gates run
  locally now (see `HACKING.md`).

Milestone: playable two-player hot-seat game in the editor and via `make run` on macOS.

---
## Phase 3 — iOS
- `make build-ios` (arm64 static lib) + `make export-ios` → Xcode project.
- Run via "Designed for iPad" (free account) or a physical device (paid account).

Milestone: the game runs on iOS (simulator or device).

---
## Phase 4 — Web / WASM
- Install emsdk + Rust nightly + `rust-src` + `wasm32-unknown-emscripten`.
- `make build-wasm` (`--features nothreads -Zbuild-std`) + `make export-web`.

Milestone: the game runs in a browser (no SharedArrayBuffer required).

---
## Phase 5 — Windows + full CI
- `build-windows` target (proven on a Windows CI runner if not cross-compilable locally).
- CI `godot` (headless smoke) and `wasm` jobs alongside the `rust` gate.

Milestone: CI green across all jobs; a Windows artifact is produced.

---
## Post-v1 — Robot (AI) mode
- `core::best_move(&Board, Player) -> usize` (minimax) behind the existing AI hook.
- Scene toggle for single-player vs. hot-seat.

Milestone: a beatable/unbeatable single-player mode, AI logic fully unit-tested.

---
## Later platforms — Android, Linux
- Android: JDK + Android SDK/NDK + Godot Android export.
- Linux: desktop export; likely already covered by the CI `godot` job's runner.

Milestone: install/run confirmed on each.

## Notes
- **Consoles are out of scope** (see `ARCHITECTURE.md`): no first-party Godot
  console export; requires a commercial porting partner under NDA.
- Windows is deliberately last of the "core four" because cross-compiling
  Godot+Rust from macOS is awkward; CI is the pragmatic path.
