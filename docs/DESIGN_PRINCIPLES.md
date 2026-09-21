# Design Principles
---
The handful of rules that shape this codebase. Read this alongside
`ARCHITECTURE.md` (technical) and `ROADMAP.md` (implementation order).
This is a living document.
---

## 1. Logic in Rust, I/O in Godot
Game rules live in `tictactoe-core`, which has **no engine dependency** and is
fully unit-tested with `cargo test`. Godot handles rendering, input, audio, and
platform packaging. If a piece of behavior can be decided without a screen or a
button, it belongs in the core. This is what makes the logic reusable and the
tests fast and deterministic.

## 2. The binding is a translator, not a brain
`tictactoe-godot` turns engine events into core calls and core results into
signals. It holds no rules. A bug in "did X win?" is a core bug; a bug in "the
cell didn't repaint" is a binding/scene bug. Keeping this line sharp keeps
debugging cheap.

## 3. Input is abstract from day one
All input flows through Godot **InputMap actions** (`cursor_up/down/left/right`,
`place`, `reset`), never hard-coded to a single device. Mouse, touch, keyboard,
and gamepad map to the same actions, and the core only ever hears "place at cell
N." This is what lets the same game run on desktop, mobile, and (hypothetically)
a controller-driven port without touching game logic.

## 4. Design for the fast-follow, don't build it early
The core exposes seams for planned features before they exist — e.g. an AI
`best_move` hook for the robot mode — so adding them is filling a body, not
reshaping an API. But we don't implement speculative features ahead of their
phase.

## 5. Tiny dependency tree
Favor `std` and hand-rolled simplicity over pulling crates into the core (the
previous project hand-rolled its RNG to stay WASM-friendly). Fewer deps means
faster builds, smaller wasm, and fewer cross-platform surprises.

## 6. The build pipeline is a first-class deliverable
Tic-tac-toe is a pretext; a repeatable, documented, multi-platform build is the
point. Every platform's recipe is captured in the `Makefile` and `HACKING.md`
as it's proven, so knowledge doesn't evaporate.
