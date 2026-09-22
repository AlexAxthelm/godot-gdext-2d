# Phase 2 — Godot binding & scene (macOS): first playable hot-seat

## Context

Phase 1 (pure core rules) is complete and merged (`b55e9a6`): `tictactoe-core`
has the full engine-free rules — `try_play`, `winner`, `is_draw`, `state`,
bounds-safe `get` — all `cargo test`-covered, zero Godot dependency. The Godot
binding crate is still a Phase 0 stub: only the `#[gdextension]` entry point
exists; there is no node, no scene, no input wiring.

Phase 2 turns that into the **first playable build**: a local two-player
hot-seat tic-tac-toe running on macOS from `make run` and from the Godot 4.7.1
editor. This is the phase that first exercises the Rust↔Godot boundary the whole
project is built to prove (`ARCHITECTURE.md`, `DESIGN_PRINCIPLES.md`).

### Decisions locked (from Q&A this session)

- **Wiring split:** *Thin GDScript view.* The Rust `TicTacToe` node is the model
  (owns `core::Board`, exposes `#[func]` methods, emits `#[signal]`s). A small,
  fully-typed `main.gd` forwards input to it and repaints on its signals. Game
  rules never leave the core; the shim stays "brainless" (Design Principle #2).
- **Scene authoring:** *Authored in `main.tscn`* (presentation lives in Godot,
  Principle #1). Node references use `@export`/`%unique-name`, not stringly `$`.
- **Input scope:** All of mouse/touch + keyboard + gamepad land **on this branch
  before merge**, sequenced: mouse/touch first (fastest path to "playable"),
  then keyboard/gamepad grid navigation.
- **GDScript safety stack:** typed GDScript + warnings-as-errors + a headless
  `--check-only` parse gate + `@export`/`%` refs, **plus one headless GdUnit4
  scene smoke test**. (See "Future GD test suites" for where fuller suites pay
  off later.)
- **gdtoolkit:** added now — `gdlint`/`gdformat` wired into `make` beside the
  Rust fmt/lint gates.

Per global policy: all work is left in the working tree — **no commits/pushes**.
Phase-per-branch is the convention; the user branches/commits themselves.

---

## Work plan

### Part A — Rust binding: the `TicTacToe` node
File: `rust/godot/src/lib.rs` (plus a `node.rs` module if it grows).

Add a registered node that is the *translator* between engine and core:

```rust
#[derive(GodotClass)]
#[class(base=Node)]                     // non-visual model node; lives in the scene
struct TicTacToe { board: Board, base: Base<Node> }
```

Public API (`#[godot_api]`), all Godot-friendly types:
- Signals:
  - `cell_changed(idx: i64, mark: GString)` — emitted per successful move; `mark`
    is `"X"`/`"O"`.
  - `turn_changed(turn: GString)` — status while in progress (`"X"`/`"O"`).
  - `game_over(outcome: GString, line: PackedInt32Array)` — `outcome` is
    `"X"`/`"O"`/`"draw"`; `line` is the three winning indices (empty for a draw)
    so the view can highlight it (`winner()` already returns the line).
- Methods:
  - `play(idx: i64) -> bool` — translate to `board.try_play(idx as usize)`.
    Guard `idx < 0` first (reject); rely on the core's bounds-safe rejection
    otherwise. On `Ok`: emit `cell_changed`, then read `board.state()` and emit
    `turn_changed` **or** `game_over`. On `Err(MoveError)`: no state change,
    return `false` (illegal clicks are silently ignored by the UI).
  - `reset()` — `board.reset()` then emit a fresh `turn_changed("X")` (and let the
    view clear all cells).
  - Read accessors for the view's initial paint: `status_text() -> GString`,
    `cell_mark(idx) -> GString`.

Keep the FFI boundary panic-free: only `board.get`/`try_play` (bounds-safe) are
called with engine indices — never the panicking `board.cell` (board.md note).
Reuses everything from `rust/core/src/lib.rs`; adds **no** rules.

### Part B — Scene: `main.tscn` + thin `main.gd`
New files: `godot/main.tscn`, `godot/main.gd`. Set `run/main_scene =
res://main.tscn` in `godot/project.godot`.

- Root: `Control` named `Main`, `main.gd` attached.
- Children (all `%unique-name` for safe refs): a `GridContainer` (columns=3) of 9
  focusable `Button`s (`Cell0`..`Cell8`), a `Label` (`Status`), a `Button`
  (`Reset`), and the Rust `TicTacToe` node (`%Board`).
- `main.gd` (fully typed):
  - `@onready`/`@export` refs to the buttons, status, reset, and `%Board`.
  - Connect each cell button `pressed` → `_on_cell_pressed(i)` → `board.play(i)`.
  - Connect `board.cell_changed` → set that button's text; `turn_changed` → set
    status label; `game_over` → set status + highlight `line` (e.g. modulate the
    three buttons) + disable further placement until reset.
  - `Reset.pressed` → `board.reset()` + clear button texts/highlights.
  - No rules — only presentation. Prefer connecting signals in the editor's
    signal panel where practical (validates names against the registered class).

### Part C — Input actions (mouse/touch first, then keyboard/gamepad)
File: `godot/project.godot` (`[input]` section) + `main.gd`.

Define the InputMap actions from `docs/features/input-actions.md`:
`cursor_up/down/left/right`, `place`, `reset`, each with keyboard **and** joypad
default events (arrows/WASD + D-pad/stick; Enter/Space + joypad A; R + Start).

- **Step 1 (playable):** mouse/touch already works via button `pressed` (Part B).
- **Step 2 (keyboard/gamepad):** drive a grid selection. Lean on Godot's built-in
  Control focus system — set the 3×3 focus neighbors so `cursor_*` moves focus
  between cell buttons and the focused button is visibly highlighted; `place`
  presses the focused button; `reset` fires the reset. Handle the actions in
  `main.gd` `_unhandled_input` using `Input.is_action_just_pressed`. Keeps the
  core hearing only "place at cell N."

### Part D — Build/run + GD tooling
File: `Makefile`, `godot/project.godot`, new CI + test files.

- `make run` (deps `rust-build`) → `godot --path godot` (plays `main.tscn` against
  the debug `libtictactoe.dylib` the `.gdextension` already maps).
- GDScript gates (fan into the top-level `check`):
  - `gd-check` → `godot --headless --check-only --script godot/main.gd`
    (verified available in Godot 4.7.1: `--check-only` used with `--script`).
  - `gd-lint` → `gdlint godot/`; `gd-format-check` → `gdformat --check godot/`;
    `gd-format` → `gdformat godot/`.
  - `smoke` → run the GdUnit4 headless test (exact CLI invocation confirmed at
    implementation, ~`godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test`).
- Extend `check` aggregate: `check: rust-all-checks gd-all-checks` where
  `gd-all-checks: gd-check gd-lint gd-format-check`. (`smoke` runs separately /
  in the smoke target since it loads the extension.)
- GdUnit4: install the addon under `godot/addons/gdUnit4/` (AssetLib or vendored),
  add `godot/test/test_main_smoke.gd`: load `main.tscn`, simulate a `place` on an
  empty cell (GdUnit4 scene runner), assert the button text and status label
  updated and that `game_over` highlights the line on a won game. This test is
  the real safety net for broken node refs / renamed signals, and seeds the
  Phase 5 headless-smoke CI job.
- CI: add a lightweight `gdscript-lint` workflow now (pure `pip install gdtoolkit`,
  runs `gdlint`/`gdformat --check` — no Godot binary needed). The **Godot-dependent**
  CI jobs (`--check-only` + smoke, which need Godot installed on the runner) stay
  deferred to the Phase 5 `godot` job per `ROADMAP.md`; they run locally via `make`
  now. (Drop the CI workflow if you'd rather keep all CI in Phase 5 — say so.)

### Part E — Docs updates (living docs)
- Flip status sections from "Phase 2 (planned)" to implemented, with the actual
  shape, in: `docs/features/board.md`, `input-actions.md`, `gameplay-hotseat.md`,
  `platform-macos.md`.
- `ROADMAP.md`: mark Phase 2 `*(done)*`; keep the note that the CI `godot` job is
  Phase 5.
- `ARCHITECTURE.md`: update "Current state"; document the thin-GDScript-view
  boundary and the GD safety stack (typed GD + warnings-as-errors + `--check-only`
  + scene smoke test).
- `HACKING.md`: add `make run` / `gd-*` / `smoke`; prerequisites for `gdtoolkit`
  (`pipx install gdtoolkit`) and the GdUnit4 addon; the macOS play loop.

---

## Commit strategy
Favor **small, atomic commits** — each compiles and does one thing. The parts
above are not one commit each; they split along dependency and reviewability
lines. Recommended order (Conventional Commits; I'll draft a message per unit,
you commit — no commits/pushes from me):

1. **Rust node** (Part A) — `feat: add TicTacToe gdext node bridging core to
   signals`. Compiles standalone; no scene yet.
2. **Playable scene, mouse/touch** (Part B + input Step 1 + `make run` +
   `run/main_scene`) — `feat: playable hot-seat scene (mouse/touch) + make run`.
   First "it plays" commit.
3. **Keyboard + gamepad** (Part C Step 2 + the `[input]` actions) —
   `feat: keyboard + gamepad grid navigation via InputMap`.
4. **GD lint/format/check gates** (Part D `gd-*` make targets + gdtoolkit) —
   `build: wire gdlint/gdformat/--check-only into make`.
5. **Smoke test** (Part D GdUnit4 addon + `test_main_smoke.gd` + `smoke` target) —
   `test: headless GdUnit4 scene smoke test`.
6. **CI lint job** (Part D, optional) — `ci: add gdscript lint workflow`.
7. **Docs** (Part E) — `docs: mark Phase 2 done; document GD view + safety stack`.

Doc status-flips may instead ride with the feature commit that implements them if
that reads more atomically at implementation time; keep each commit self-consistent.

## Critical files
- `rust/godot/src/lib.rs` — add the `TicTacToe` node (Part A). Reuses
  `rust/core/src/lib.rs` (`Board`, `try_play`, `state`, `winner`) unchanged.
- `godot/main.tscn`, `godot/main.gd` — scene + thin typed view (Parts B/C).
- `godot/project.godot` — `[input]` actions + `run/main_scene` (Parts B/C).
- `Makefile` — `run`, `gd-*`, `smoke`, extended `check` (Part D).
- `godot/test/test_main_smoke.gd` + `godot/addons/gdUnit4/` — smoke test (Part D).
- `.github/workflows/` — optional `gdscript-lint` job (Part D).
- `docs/*` — status/architecture/hacking updates (Part E).

## Verification (end-to-end)
1. `make check` green (Rust gates **and** `gd-check`/`gd-lint`/`gd-format-check`).
2. `make smoke` — GdUnit4 headless scene test passes.
3. `make run` on macOS, play a full hot-seat game:
   - **Mouse/touch:** clicking empty cells alternates X/O; status shows the turn;
     completing a line highlights those three cells + announces the winner; a
     full no-line board shows "Draw"; clicking played/other cells after game-over
     does nothing; Reset clears to an empty board, X to move.
   - **Keyboard:** arrows/WASD move the focus highlight; Enter/Space places; R
     resets.
   - **Gamepad:** D-pad/stick move; A places; Start resets.
4. Open `godot/` in the Godot 4.7.1 editor — extension loads with no error, scene
   plays (Phase 0 milestone still holds).

*(Offer: I can run `make run` and eyeball the window via screenshots if you want a
second pair of eyes during verification.)*

## Future GD test suites (noted per request)
The single smoke test is deliberately minimal — the shim is thin and the logic is
already `cargo test`-covered in the core. A fuller GdUnit4 suite becomes worth it
when scene logic grows: the **Post-v1 robot mode** (a hot-seat/vs-robot toggle,
AI-turn flow) and any animation/theming work will have real view state and input
sequencing worth asserting with GdUnit4's scene runner. **Phase 5** formalizes the
Godot-headless CI job (`--check-only` + smoke) — the smoke test written here is its
seed, and that's the natural point to expand GD coverage and add `gdformat` as a
CI-enforced format gate alongside the Rust one.
