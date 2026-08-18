INPUT ?= ../../../../corp-web-v2/src/content/legal/eula/en/index.md
CONFIG ?= document.json
CONFIG_PATH := $(abspath $(CONFIG))
LAST_UPDATED := $(shell sed -n 's/.*"last_updated": "\([0-9-]*\)".*/\1/p' "$(CONFIG_PATH)")
OUTPUT ?= eula-$(LAST_UPDATED).pdf

.PHONY: pdf verify test

pdf:
	./build_eula.py \
		--input "$(INPUT)" \
		--config "$(CONFIG_PATH)" \
		--output "$(OUTPUT)"

verify:
	./verify_eula.py \
		--pdf "$(OUTPUT)" \
		--input "$(INPUT)" \
		--config "$(CONFIG_PATH)"

test:
	./test_eula.py
