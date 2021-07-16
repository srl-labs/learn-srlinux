.PHONY: docs
docs:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs squidfunk/mkdocs-material:7.1.8 build --clean --strict

.PHONY: site
serve:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs squidfunk/mkdocs-material:7.1.8
