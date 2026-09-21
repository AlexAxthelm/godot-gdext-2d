# Contributing
---
How work lands in this repo. Small project, light process — but consistent.
---

## Workflow
- Work one **phase per branch** (see `docs/ROADMAP.md`). Branch names describe
  the change: `feat/core-rules`, `feat/macos-scene`, `docs/add-glossary`,
  `fix/wasm-linker-flags`.
- Open a PR that ties to a roadmap phase or an existing discussion.
- **`make check` and `make test` must pass** before requesting review.

## Commits
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `chore:`, `ci:`, …).
- Keep the Rust core changes and the Godot binding changes legible as separate
  concerns where practical.

## Code conventions
- Game rules go in `tictactoe-core` and must be unit-tested; the `tictactoe-godot`
  crate stays a thin translator (see `docs/DESIGN_PRINCIPLES.md`).
- No new dependency in `tictactoe-core` without a clear reason — keep it tiny and
  WASM-friendly.
- `clippy -- -D warnings` is clean; no committed warnings.

## Docs
- Update the relevant `docs/` file for any user-facing or structural change.
  Docs are enforced by review, not tooling.

## What not to commit
- `rust/target/` and generated `godot/.godot/` caches (see `.gitignore`).
- Do commit `godot/.godot/extension_list.cfg` — Godot needs it to load the
  extension on a fresh clone.
