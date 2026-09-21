# Tic-Tac-Toe — Rust core + Godot (gdext)

A cross-platform tic-tac-toe game with **game logic in Rust** and **rendering /
I/O in Godot 4.7** (via [gdext](https://github.com/godot-rust/gdext)). The game
is deliberately simple — the goal is a clean, reusable skeleton and a proven
multi-platform build pipeline (macOS, iOS, Windows, Web, later Android/Linux).

## Status

**Phase 0 — skeleton & docs.** The workspace builds, the pure-core tests pass,
and the Godot project registers the extension. No gameplay yet. See
[`docs/ROADMAP.md`](docs/ROADMAP.md) for what lands next.

## Layout

```
rust/    Cargo workspace: `core` (pure rules, no engine) + `godot` (gdext binding)
godot/   the Godot project (open this in the editor)
docs/    architecture, roadmap, hacking guide, feature specs
Makefile build/check/test/run orchestration — `make help`
```

## Quickstart

```sh
make build   # debug build of the Rust workspace
make check   # cargo check + clippy -D warnings
make test    # pure-core unit tests (no engine)
```

Then build once and open `godot/` in **Godot 4.7.1** to load the extension.

## Docs

- [Architecture](docs/ARCHITECTURE.md) — the two-crate split and the Rust↔Godot boundary
- [Design principles](docs/DESIGN_PRINCIPLES.md) — logic in Rust, I/O in Godot
- [Roadmap](docs/ROADMAP.md) — phased plan
- [Hacking](docs/HACKING.md) — setup and per-platform toolchain notes
- [Contributing](docs/policies/CONTRIBUTING.md)
