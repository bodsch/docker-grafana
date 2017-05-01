docker-grafana
==============

A Docker container for an (currently) actual Grafana Webinterface build from Source.


# Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-grafana.svg?branch=1705-01)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-grafana.svg?branch=1705-01)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-grafana.svg?branch=1705-01)][travis]

[hub]: https://hub.docker.com/r/bodsch/docker-grafana/
[microbadger]: https://microbadger.com/images/bodsch/docker-grafana
[travis]: https://travis-ci.org/bodsch/docker-grafana


# Build

Your can use the included Makefile.

To build the Container: `make build`

To remove the builded Docker Image: `make clean`

Starts the Container: `make run`

Starts the Container with Login Shell: `make shell`

Entering the Container: `make exec`

Stop (but **not kill**): `make stop`

History `make history`


# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-grafana/)


# supported Environment Vars

`ORGANISATION` to change the Organization Name (default: Docker)

`DATABASE_TYPE` to change the Type of Database. Supportet Types are mysql and sqlite3 (default: sqlite3)

`MYSQL_HOST` the MySQL Hostname

`MYSQL_PORT` the MySQL Port (default: `3306`)

`MYSQL_ROOT_USER` MySQL Root Username (default: `root`)

`MYSQL_ROOT_PASS` MySQL Root Password

`GRAPHITE_HOST` the graphite Hostname

`GRAPHITE_HTTP_PORT` the graphite HTTP Port (default: `8080`)

`CARBON_HOST` the carbon Hostname to send internal Grafana metrics, can be identical with `GRAPHITE_HOST`

`CARBON_PORT` the carbon Port (default: `2003`)

`MEMCACHE_HOST` the memcache Hostname to store Sessions

`MEMCACHE_PORT` the memcache Port (default: `11211`)

`DATABASE_GRAFANA_PASS` the Database Password for Grafana (default: grafana)


# includes

 - grafana plugins
     * grafana-clock-panel
     * grafana-piechart-panel
     * jdbranham-diagram-panel
     * mtanda-histogram-panel
     * btplc-trend-box-panel


# Ports
 - 3000: grafana (plain)
