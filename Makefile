# Tic-Tac-Toe — Rust core + Godot (gdext) build orchestration.
#
# Aggregate targets fan out to language-scoped groups; each granular target maps
# 1:1 to a CI check (see .github/workflows/). Per-platform targets (ios / wasm /
# windows) and Godot run/export targets are added with their phases — see
# docs/ROADMAP.md.

check: rust-all-checks
test: rust-test
lint: rust-lint
format-check: rust-format-check
format: rust-format
clean: rust-clean

# -- Rust --
# The Cargo workspace lives under rust/, so every target runs from there. (This
# also lets `cargo fmt`, which doesn't accept --manifest-path, just work.)
RUST_DIR := rust

rust-all-checks: rust-check rust-test rust-lint rust-format-check rust-lock-check

rust-check:
	cd $(RUST_DIR) && cargo check

rust-test:
	cd $(RUST_DIR) && cargo test -p tictactoe-core

rust-lint:
	cd $(RUST_DIR) && cargo clippy -- -D warnings

rust-format:
	cd $(RUST_DIR) && cargo fmt

rust-format-check:
	cd $(RUST_DIR) && cargo fmt -- --check

rust-lock-check:
	cd $(RUST_DIR) && cargo check --locked

rust-build:
	cd $(RUST_DIR) && cargo build

rust-clean:
	cd $(RUST_DIR) && cargo clean

.PHONY: check test lint format format-check clean \
        rust-all-checks rust-check rust-test rust-lint \
        rust-format rust-format-check rust-lock-check rust-build rust-clean
