# Tic-Tac-Toe — Rust core + Godot (gdext) build orchestration.
#
# Phase 0 exercises: build, check, test, clean.
# Later-phase targets (ios/wasm/windows/export/run) are wired now but are not
# exercised until their respective phases — see docs/ROADMAP.md.

GODOT         ?= godot
CARGO         ?= cargo
RUST_DIR      := rust
GODOT_DIR     := godot
GODOT_VERSION := 4.7.1.stable.official

MANIFEST := $(RUST_DIR)/Cargo.toml

.DEFAULT_GOAL := build

# ── Rust: build ───────────────────────────────────────────────────────────────
.PHONY: build build-release
build:                       ## Debug build of the whole workspace
	$(CARGO) build --manifest-path $(MANIFEST)
build-release:               ## Release build of the whole workspace
	$(CARGO) build --release --manifest-path $(MANIFEST)

# ── Rust: quality gates (Phase 0 milestone) ───────────────────────────────────
.PHONY: check test
check:                       ## cargo check + clippy (warnings are errors)
	$(CARGO) check --manifest-path $(MANIFEST)
	$(CARGO) clippy --manifest-path $(MANIFEST) -- -D warnings
test:                        ## Pure-core unit tests (no Godot needed)
	$(CARGO) test -p tictactoe-core --manifest-path $(MANIFEST)

.PHONY: clean
clean:                       ## Remove Rust build artifacts
	$(CARGO) clean --manifest-path $(MANIFEST)

# ── iOS (Phase 3 — not yet exercised) ─────────────────────────────────────────
.PHONY: build-ios build-ios-release
build-ios:
	$(CARGO) build --manifest-path $(MANIFEST) --target aarch64-apple-ios
build-ios-release:
	$(CARGO) build --release --manifest-path $(MANIFEST) --target aarch64-apple-ios

# ── Web / WASM (Phase 4 — needs nightly + rust-src + emsdk) ────────────────────
.PHONY: build-wasm build-wasm-release
build-wasm:
	cd $(RUST_DIR)/godot && \
	$(CARGO) +nightly build --features nothreads -Zbuild-std \
		--target wasm32-unknown-emscripten
build-wasm-release:
	cd $(RUST_DIR)/godot && \
	$(CARGO) +nightly build --release --features nothreads -Zbuild-std \
		--target wasm32-unknown-emscripten

# ── Windows (Phase 5 — best effort locally; usually proven on CI) ──────────────
.PHONY: build-windows
build-windows:
	$(CARGO) build --manifest-path $(MANIFEST) --target x86_64-pc-windows-gnu

# ── Godot: run / import (Phase 2 — needs a main scene) ─────────────────────────
.PHONY: run run-editor import
run: build                   ## Headless smoke run of the main scene
	$(GODOT) --headless --path $(GODOT_DIR) --quit-after 2
run-editor: build            ## Open the project in the Godot editor
	$(GODOT) --editor --path $(GODOT_DIR) &
import:                      ## Warm the import cache (CI/fresh clone)
	$(GODOT) --headless --path $(GODOT_DIR) --import --quit || true

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:                        ## List documented targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'
