set shell := ["sh", "-cu"]
set windows-shell := ["cmd.exe", "/d", "/c"]

all: fmt-check lint test

fmt-check:
    stylua --check lua --config-path=.stylua.toml

lint:
    luacheck lua --globals vim

test:
    nvim --headless --clean -i NONE -l tests/run.lua

test-spec spec:
    nvim --headless --clean -i NONE -l tests/run.lua "{{ spec }}"

test-integration:
    nvim --headless --clean -i NONE -l tests/run.lua tests/integration

test-debug:
    nvim --headless --noplugin -i NONE -u tests/minimal_init.lua -l tests/native_debug.lua
