TYPE := grafana
IMAGE_NAME := docker-${TYPE}

build:
	docker build --rm --tag=$(IMAGE_NAME) .

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--publish=3000:3000 \
		--hostname=graphite \
		--name=${TYPE} \
		$(IMAGE_NAME)

shell:
	docker run \
    --rm \
		--interactive \
    --tty \
    --publish=3000:3000 \
		--hostname=graphite \
		--name=${TYPE} \
		$(IMAGE_NAME) \
    /bin/sh

exec:
	docker exec \
		--interactive \
		--tty \
		${TYPE} \
		/bin/sh

stop:
	docker kill \
		${TYPE}
