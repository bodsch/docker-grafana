
CONTAINER  := grafana
IMAGE_NAME := docker-grafana

DATA_DIR   := /tmp/docker-data


build:
	mkdir -vp ${DATA_DIR}
	docker \
		build \
		--rm --tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

run:
	docker \
		run \
		--detach \
		--interactive \
		--tty \
		--publish=3000:3000 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${CONTAINER} \
		--name=${CONTAINER} \
		$(IMAGE_NAME)

shell:
	docker \
		run \
		--rm \
		--interactive \
		--tty \
		--publish=3000:3000 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${CONTAINER} \
		--name=${CONTAINER} \
		$(IMAGE_NAME)

exec:
	docker \
		exec \
		--interactive \
		--tty \
		${CONTAINER} \
		/bin/bash

stop:
	docker \
		kill ${CONTAINER}

history:
	docker \
		history ${IMAGE_NAME}
