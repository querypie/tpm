INPUT := ../../../../corp-web-v2/src/content/legal/eula/en/index.md
OUTPUT := eula-2026-04-10.pdf

.PHONY: pdf verify test

pdf:
	./build_eula.py \
		--input "$(INPUT)" \
		--output "$(OUTPUT)"

verify:
	./verify_eula.py \
		--input "$(INPUT)" \
		--output "$(OUTPUT)"

test:
	./test_eula.py
