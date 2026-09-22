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

# Our own GDScript (exclude the fetched GdUnit4 addon — not ours to lint/format).
# gdlint/gdformat need no engine, so they cover the test suite too.
GD_SOURCES := $(shell find $(GODOT_DIR) -name '*.gd' -not -path '*/addons/*')
# gd-check additionally excludes test/: those scripts extend GdUnit4's
# GdUnitTestSuite, so type-checking them needs the addon (see `make smoke`). This
# keeps `make check` runnable on a fresh clone with no test deps fetched.
GD_CHECK_SOURCES := $(shell find $(GODOT_DIR) -name '*.gd' -not -path '*/addons/*' -not -path '*/test/*')

# GdUnit4 is fetched on demand (see gd-test-deps), not vendored; pin the version.
GDUNIT_VERSION := v6.2.1
GDUNIT_DIR := $(GODOT_DIR)/addons/gdUnit4
GDUNIT_RUNNER := res://addons/gdUnit4/bin/GdUnitCmdTool.gd

run: rust-build
	godot --path $(GODOT_DIR)

# The GDScript analogue of rust-all-checks: type-check (godot --check-only, which
# honours the warnings-as-errors in project.godot), lint, and format-check.
gd-all-checks: gd-check gd-lint gd-format-check

# `--check-only` parses + type-checks one script and quits; loop over ours so a
# typo or unsafe access fails the build. Needs Godot on PATH (see HACKING.md).
gd-check:
	@for f in $(GD_CHECK_SOURCES); do \
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

# Fetch the pinned GdUnit4 test framework into the (gitignored) addons dir if it
# isn't already there. Kept out of the repo per the "pin, don't vendor" approach.
gd-test-deps:
	@if [ -d "$(GDUNIT_DIR)" ]; then \
		echo "GdUnit4 present ($(GDUNIT_DIR))"; \
	else \
		echo "Fetching GdUnit4 $(GDUNIT_VERSION)…"; \
		tmp=$$(mktemp -d); \
		git clone --depth 1 --branch $(GDUNIT_VERSION) https://github.com/MikeSchulze/gdUnit4.git "$$tmp"; \
		mkdir -p $(GODOT_DIR)/addons; \
		cp -R "$$tmp/addons/gdUnit4" "$(GDUNIT_DIR)"; \
		rm -rf "$$tmp"; \
		echo "Installed GdUnit4 → $(GDUNIT_DIR)"; \
	fi

# Headless scene smoke test (GdUnit4). The --import pass builds the global class
# cache GdUnit4's class_names need; --ignoreHeadlessMode is safe here because the
# tests drive the view via signals, not injected InputEvents. Seeds the Phase 5
# headless-smoke CI job.
smoke: rust-build gd-test-deps
	godot --headless --path $(GODOT_DIR) --import
	godot --headless --path $(GODOT_DIR) -s $(GDUNIT_RUNNER) -a res://test --ignoreHeadlessMode

.PHONY: check test lint format format-check clean \
        rust-all-checks rust-check rust-test rust-lint \
        rust-format rust-format-check rust-lock-check rust-build rust-clean \
        run gd-all-checks gd-check gd-lint gd-format gd-format-check \
        gd-test-deps smoke
