# Tic-Tac-Toe — Rust core + Godot (gdext) build orchestration.
#
# Aggregate targets fan out to language-scoped groups; each granular target maps
# 1:1 to a CI check (see .github/workflows/). Per-platform targets (ios / wasm /
# windows) and Godot run/export targets are added with their phases — see
# docs/ROADMAP.md.

check: rust-all-checks gd-all-checks
test: rust-test
lint: rust-lint gd-lint
format-check: rust-format-check gd-format-check
format: rust-format gd-format
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

# -- Godot --
# The Godot project lives under godot/; it loads the debug dylib that rust-build
# produces, so `run` depends on it.
GODOT_DIR := godot

# Our own GDScript (exclude the vendored GdUnit4 addon — its code isn't ours to
# lint/format). Used by every gd-* gate below.
GD_SOURCES := $(shell find $(GODOT_DIR) -name '*.gd' -not -path '*/addons/*')

run: rust-build
	godot --path $(GODOT_DIR)

# The GDScript analogue of rust-all-checks: type-check (godot --check-only, which
# honours the warnings-as-errors in project.godot), lint, and format-check.
gd-all-checks: gd-check gd-lint gd-format-check

# `--check-only` parses + type-checks one script and quits; loop over ours so a
# typo or unsafe access fails the build. Needs Godot on PATH (see HACKING.md).
gd-check:
	@for f in $(GD_SOURCES); do \
		echo "check-only $$f"; \
		godot --headless --path $(GODOT_DIR) --check-only -s "res://$${f#$(GODOT_DIR)/}" || exit 1; \
	done

# gdlint / gdformat come from gdtoolkit (see HACKING.md for install).
gd-lint:
	gdlint $(GD_SOURCES)

gd-format:
	gdformat $(GD_SOURCES)

gd-format-check:
	gdformat --check $(GD_SOURCES)

.PHONY: check test lint format format-check clean \
        rust-all-checks rust-check rust-test rust-lint \
        rust-format rust-format-check rust-lock-check rust-build rust-clean \
        run gd-all-checks gd-check gd-lint gd-format gd-format-check
