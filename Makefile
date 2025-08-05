MKDOCS_VER = 9.6.1
# insiders version/tag https://github.com/srl-labs/mkdocs-material-insiders/pkgs/container/mkdocs-material-insiders
# when changing the version, update the version in the cicd.yml file
MKDOCS_INS_VER = 9.6.16-insiders-4.53.16-hellt

.PHONY: docs
docs:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER) build --clean --strict

# serve the site locally using mkdocs-material public container
.PHONY: serve
serve:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs squidfunk/mkdocs-material:$(MKDOCS_VER)

# serve the site locally using mkdocs-material insiders container
.PHONY: serve-insiders
serve-insiders:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER)

# serve the site locally using mkdocs-material insiders container using dirty-reloader
.PHONY: serve-insiders-dirty
serve-insiders-dirty:
	docker run -it --rm -p 8001:8000 -v $$(pwd):/docs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER) serve --dirtyreload -a 0.0.0.0:8000

.PHONY: serve-docs
serve-docs: serve-insiders-dirty

.PHONY: htmltest
htmltest:
	docker run --rm -v $$(pwd):/docs --entrypoint mkdocs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER) build --clean --strict
	docker run --rm -v $$(pwd):/test wjdp/htmltest --conf ./site/htmltest.yml
	rm -rf ./site

build-insiders:
	docker run -v $$(pwd):/docs --entrypoint mkdocs registry.srlinux.dev/pub/mkdocs-material-insiders:$(MKDOCS_INS_VER) build --clean --strict

push-docs: # push docs to gh-pages branch manually. Use when pipeline misbehaves
	docker run -v ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent --env GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -v $$(pwd):/docs --entrypoint mkdocs ghcr.io/srl-labs/mkdocs-material-insiders:$(MKDOCS_INS_VER) gh-deploy --force --strict

add-no-index: # replace noindex commen in main template to include robots noindex instruction. This is needed prior pushing to staging, so that staging is not indexed by robots
	sed -i 's/<!-- NOINDEX -->/<meta name="robots" content="noindex">/g' docs/overrides/main.html

# build html docs and push to staging1 server - https://hellt.github.io/learn-srlinux-stage1
push-to-staging1: add-no-index build-insiders
	# revert changes to main so that main.html remains unchanged
	git checkout docs/overrides/main.html
	rm -rf ~/hellt/learn-srlinux-stage1/*
	cp -a site/* ~/hellt/learn-srlinux-stage1
	cd ~/hellt/learn-srlinux-stage1 && echo 'stage1.learn.srlinux.dev' > CNAME && git add . && git commit -m "update" && git push --force
