export GIT_SHA1          := $(shell git rev-parse --short HEAD)
export DOCKER_IMAGE_NAME := grafana
export DOCKER_NAME_SPACE := ${USER}
export DOCKER_VERSION    ?= latest
export BUILD_DATE        := $(shell date +%Y-%m-%d)
export BUILD_VERSION     := $(shell date +%y%m)
export BUILD_TYPE        ?= stable
export GRAFANA_VERSION   ?= 6.2.0-beta2


.PHONY: build shell run exec start stop clean

default: build

build:
	@hooks/build

hell:
	@hooks/shell

run:
	@hooks/run

exec:
	@hooks/exec

shell:
	@hooks/shell
start:
	@hooks/start

stop:
	@hooks/stop

clean:
	@hooks/clean

compose-file:
	@hooks/compose-file

linter:
	@tests/linter.sh

integration_test:
	@tests/integration_test.sh

test: linter integration_test
