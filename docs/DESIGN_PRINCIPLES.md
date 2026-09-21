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

## 5. Depend deliberately, not reflexively
Prefer a well-maintained library over hand-rolling anything non-trivial —
hand-rolled math, parsers, and algorithms are a classic source of subtle bugs
(an LCG with poor constants, an off-by-one in a tokenizer). A small dependency
tree is not itself a goal, and dependency *count* is not what breaks WASM.

What breaks WASM is a specific, short list of *capabilities*. Vet each new
dependency against it before adding — reject or feature-gate the ones that fail:

- **Entropy** — anything pulling `getrandom` (e.g. `rand`'s default features).
  Fine on our `wasm32-unknown-emscripten` target, but a linker error on
  `wasm32-unknown-unknown` without the `js` feature.
- **Thread spawning** — we build with `experimental-wasm-nothreads`, so
  `std::thread::spawn`, `rayon`, etc. will not work. (Atomic *types* are fine
  single-threaded; it's spawning that dies.)
- **C deps / native `build.rs`** — crates that compile C or link system
  libraries are painful-to-impossible to cross-compile under emscripten.
- **Time / I/O** — `Instant`/`SystemTime` can panic on wasm; fs and net are
  environment-specific.
- **Shipped size** — every dep adds to the `.wasm` the browser downloads. A real
  but usually modest cost.

Control something yourself only when there's a *design* reason — e.g. a seedable,
deterministic RNG for reproducible tests, replays, or future netcode — not merely
to keep the dependency count down. In that RNG case the answer is a vetted small
crate (`rand_pcg`, `fastrand`) seeded manually, not a hand-rolled generator.

## 6. The build pipeline is a first-class deliverable
Tic-tac-toe is a pretext; a repeatable, documented, multi-platform build is the
point. Every platform's recipe is captured in the `Makefile` and `HACKING.md`
as it's proven, so knowledge doesn't evaporate.
