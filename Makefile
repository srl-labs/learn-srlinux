MKDOCS_VER = 8.2.9
# insiders version/tag https://github.com/srl-labs/mkdocs-material-insiders/pkgs/container/mkdocs-material-insiders
MKDOCS_INS_VER = 8.2.9-insiders-4.12.0

.PHONY: docs
docs:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs squidfunk/mkdocs-material:$(MKDOCS_VER) build --clean --strict

# serve the site locally using mkdocs-material public container
.PHONY: serve
serve:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs squidfunk/mkdocs-material:$(MKDOCS_VER)

# serve the site locally using mkdocs-material insiders container
.PHONY: serve-insiders
serve-insiders:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs ghcr.io/srl-labs/mkdocs-material-insiders:$(MKDOCS_INS_VER)

.PHONY: htmltest
htmltest:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs ghcr.io/srl-labs/mkdocs-material-insiders:$(MKDOCS_INS_VER) build --clean --strict
	docker run --rm -v $$(pwd):/test wjdp/htmltest --conf ./site/htmltest.yml
	rm -rf ./site