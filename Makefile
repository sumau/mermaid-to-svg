IMAGE := minlag/mermaid-cli:11.16.0

.PHONY: diagrams test

# Render all Mermaid sources to SVG. Commit the result alongside the source.
diagrams:
	./render.sh

# Run the Markdown-extractor tests using the pinned image's Node.
test:
	docker run --rm -v "$$PWD":/data --entrypoint node $(IMAGE) \
		--test /data/scripts/extract-mermaid.test.mjs
