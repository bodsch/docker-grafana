docker-grafana
==============

A Docker container for an (currently) actual Grafana Webinterface build from Source.

this container use phantomjs from [Overbryd](https://github.com/Overbryd/docker-phantomjs-alpine)

# Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-grafana.svg?branch=1707-30)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-grafana.svg?branch=1707-30)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-grafana.svg?branch=1707-30)][travis]

[hub]: https://hub.docker.com/r/bodsch/docker-grafana/
[microbadger]: https://microbadger.com/images/bodsch/docker-grafana
[travis]: https://travis-ci.org/bodsch/docker-grafana


# Build

Your can use the included Makefile.

To build the Container: `make build`

To remove the builded Docker Image: `make clean`

Starts the Container with a simple set of environment vars: `make start`

Starts the Container with Login Shell: `make shell`

Entering the Container: `make exec`

Stop (but **not kill**): `make stop`

see the History `make history`


# docker-compose

I've put a small `docker-compose` Example in the current branch.

## To start the Example:

    docker-compose -f docker-compose_example.yml up --build

## to destroy

    docker-compose -f docker-compose_example.yml kill
    docker-compose -f docker-compose_example.yml down


# automatic Dashboard import

Dashboards Templates under `rootfs/opt/grafana/dashboards` will be automatic imported at start.


# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-grafana/)


# supported Environment Vars

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `DATABASE_TYPE`                    | `sqlite3`            | supportet Types are `mysql` and `sqlite3`                       |
| `ORGANISATION`                     | `Docker`             | to change the Organization Name                                 |
| `URL_PATH`                         | `/`                  | to change the Path in the URL whe they run behind a proxy (example: `/grafana/`) |
| `GRAFANA_USERS`                    | -                    | comma separated List to create Grafana Users.                   |
|                                    |                      | The Format are `username:password:email:role`                        |
|                                    |                      | (e.g. `admin:admin:admin@domain.tld:admin,grafana:garafan::` and so on) |
|                                    |                      | if the email field not set, he will be autocreate as `username@foo-bar.tld` |
|                                    |                      | if the role field not set, the Role `Viewer` will be used. Currentl, only `Viewer` and `Admin` is supported |
|                                    |                      |                                                                 |
| `MYSQL_HOST`                       | -                    | MySQL Host                                                      |
| `MYSQL_PORT`                       | `3306`               | MySQL Port                                                      |
| `MYSQL_ROOT_USER`                  | `root`               | MySQL root User                                                 |
| `MYSQL_ROOT_PASS`                  | -                    | MySQL root password                                             |
| `SQLITE_PATH`                      | -                    | set the Storage-Path for a `sqlite` Database                    |
| `DATABASE_GRAFANA_PASS`            | `grafana`            | the Database Password for Grafana                               |
|                                    |                      |                                                                 |
| `GRAPHITE_HOST`                    | -                    | the graphite Hostname                                           |
| `GRAPHITE_PORT`                    | `2003`               | the graphite Port                                               |
| `GRAPHITE_HTTP_PORT`               | `8080`               | the graphite HTTP Port                                          |
|                                    |                      |                                                                 |
| `CARBON_HOST`                      | -                    | the carbon Hostname to send internal Grafana metrics, can be identical with `GRAPHITE_HOST` |
| `CARBON_PORT`                      | `2003`               | the carbon Port                                                 |
|                                    |                      |                                                                 |
| `MEMCACHE_HOST`                    | -                    | the memcache Hostname to store Sessions                         |
| `MEMCACHE_PORT`                    | `11211`              | the memcache Port                                               |
|                                    |                      |                                                                 |


# includes

 - grafana plugins
     * grafana-clock-panel
     * grafana-piechart-panel
     * jdbranham-diagram-panel
     * mtanda-histogram-panel
     * btplc-trend-box-panel


# Ports

 - `3000`: grafana (plain)
