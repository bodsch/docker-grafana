
include env_make

NS       = bodsch
VERSION ?= latest

REPO     = docker-grafana
NAME     = grafana
INSTANCE = default

BUILD_DATE := $(shell date +%Y-%m-%d)
BUILD_VERSION := $(shell date +%y%m)

.PHONY: build push shell run start stop rm release

default: build

params:
	@echo ""
	@echo " GRAFANA_VERSION: ${GRAFANA_VERSION}"
	@echo " BUILD_DATE     : $(BUILD_DATE)"
	@echo ""

build:	params
	docker build \
		--force-rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg GRAFANA_VERSION=${GRAFANA_VERSION} \
		--tag $(NS)/$(REPO):$(VERSION) .

clean:
	docker rmi \
		--force \
		$(NS)/$(REPO):$(VERSION)

history:
	docker history \
		$(NS)/$(REPO):$(VERSION)

push:	params
	docker push \
		$(NS)/$(REPO):$(VERSION)

shell:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		--interactive \
		--tty \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(VERSION) \
		/bin/sh

run:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(VERSION)

exec:
	docker exec \
		--interactive \
		--tty \
		$(NAME)-$(INSTANCE) \
		/bin/sh

start:
	docker run \
		--detach \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(VERSION)

stop:
	docker stop \
		$(NAME)-$(INSTANCE)

rm:
	docker rm \
		$(NAME)-$(INSTANCE)

release: build
	make push -e VERSION=$(VERSION)
