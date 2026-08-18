EULA_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(EULA_DIR)/../../..)

INPUT ?= ../corp-web-v2/src/content/legal/eula/en/index.md
CONFIG ?= $(EULA_DIR)/document.json
LAST_UPDATED := $(shell sed -n 's/.*"last_updated": "\([0-9-]*\)".*/\1/p' $(CONFIG))
OUTPUT ?= output/pdf/eula-$(LAST_UPDATED).pdf
RENDER_PREFIX ?= tmp/pdfs/eula-$(LAST_UPDATED)

.PHONY: pdf verify test preview

pdf:
	cd "$(REPO_ROOT)" && "$(EULA_DIR)/build_eula.py" \
		--input "$(INPUT)" \
		--config "$(CONFIG)" \
		--output "$(OUTPUT)"

verify:
	cd "$(REPO_ROOT)" && "$(EULA_DIR)/verify_eula.py" \
		--pdf "$(OUTPUT)" \
		--input "$(INPUT)" \
		--config "$(CONFIG)"

test:
	"$(EULA_DIR)/test_eula.py"

preview: pdf
	cd "$(REPO_ROOT)" && mkdir -p "$(dir $(RENDER_PREFIX))" && \
		pdftoppm -png -r 144 "$(OUTPUT)" "$(RENDER_PREFIX)"
