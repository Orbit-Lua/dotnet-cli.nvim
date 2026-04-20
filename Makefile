.PHONY: test lint format

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/dotnet-cli"

lint:
	luac -p lua/dotnet-cli/*.lua lua/dotnet-cli/commands/*.lua

format:
	stylua lua/ tests/ plugin/

check:
	stylua --check lua/ tests/ plugin/
