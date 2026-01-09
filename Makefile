MKDOCS_VERSION ?= v9.7.1-1
MKDOCS_INET_IMAGE := ghcr.io/eda-labs/mkdocs-material:$(MKDOCS_VERSION)

.PHONY: docs
docs:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs ${MKDOCS_INET_IMAGE} build --clean --strict

# serve the doc site locally with full site rendered on each change (slower)
.PHONY: serve-docs-full
serve-docs-full:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER)

# serve the doc site locally with dirty reload (faster, but toc updates may require a manual stop/start)
.PHONY: serve-docs
serve-docs:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs ${MKDOCS_INET_IMAGE} serve --dirtyreload -a 0.0.0.0:8000

.PHONY: htmltest
htmltest:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs ${MKDOCS_INET_IMAGE} build --clean --strict
	docker run --rm -v $$(pwd):/test wjdp/htmltest --conf ./site/htmltest.yml
	rm -rf ./site

build-insiders:
	docker run -v $$(pwd):/docs --entrypoint mkdocs ${MKDOCS_INET_IMAGE} build --clean --strict

push-docs: # push docs to gh-pages branch manually. Use when pipeline misbehaves
	docker run -v ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent --env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -v $$(pwd):/docs --entrypoint mkdocs ${MKDOCS_INET_IMAGE} gh-deploy --force --strict

add-no-index: # replace noindex comment in main template to include robots noindex instruction. This is needed prior pushing to staging, so that staging is not indexed by robots
	sed -i 's/<!-- NOINDEX -->/<meta name="robots" content="noindex">/g' docs/overrides/main.html

# build html docs and push to staging1 server - https://hellt.github.io/learn-srlinux-stage1
push-to-staging1: add-no-index build-insiders
	# revert changes to main so that main.html remains unchanged
	git checkout docs/overrides/main.html
	rm -rf ~/hellt/learn-srlinux-stage1/*
	cp -a site/* ~/hellt/learn-srlinux-stage1
	cd ~/hellt/learn-srlinux-stage1 && echo 'stage1.learn.srlinux.dev' > CNAME && git add . && git commit -m "update" && git push --force
