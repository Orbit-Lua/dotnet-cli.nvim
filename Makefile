.PHONY: test lint format

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/dotnet-cli { minimal_init = 'tests/minimal_init.lua' }"

lint:
	luac -p lua/dotnet-cli/*.lua lua/dotnet-cli/commands/*.lua

format:
	stylua lua/ tests/ plugin/

check:
	stylua --check lua/ tests/ plugin/
