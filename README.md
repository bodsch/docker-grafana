docker-grafana
==============

A Docker container for an (currently) actual Grafana Webinterface build from Source.

this container use phantomjs from [Overbryd](https://github.com/Overbryd/docker-phantomjs-alpine)

# A request from me

**PLEASE** do not report any bugs for this container to the Grafana crew!

The guys are doing a great job and I also produce bugs.

Please use the [Issue Tracker](https://github.com/bodsch/docker-grafana/issues) and give me feedback!


# Current Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-grafana.svg?branch)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-grafana.svg?branch)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-grafana.svg?branch)][travis]

[hub]: https://hub.docker.com/r/bodsch/docker-grafana/
[microbadger]: https://microbadger.com/images/bodsch/docker-grafana
[travis]: https://travis-ci.org/bodsch/docker-grafana


# Build
Your can use the included Makefile.

- to build the Container: `make`
- to remove the builded Docker Image: `make clean`
- starts the Container with a simple set of environment vars: `make start`
- starts the Container with Login Shell: `make shell`
- entering the Container: `make exec`
- stop (but **not kill**): `make stop`
- see the History: `make history`


# Contribution

Please read [Contribution](CONTRIBUTIONG.md)


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

- `DATABASE_TYPE` (default: `sqlite3`)  supportet Types are `mysql` and `sqlite3`
- `URL_PATH` (default: `/`) to change the Path in the URL whe they run behind a proxy (example: `/grafana/`)
- `ORGANISATION` (default: `Docker`)
- `MYSQL_HOST` (default:`-`) MySQL Host
- `MYSQL_PORT` (default: `3306`) MySQL Port
- `MYSQL_ROOT_USER` (default:  `root`) MySQL root User
- `MYSQL_ROOT_PASS` (default:  `-`) MySQL root password
- `SQLITE_PATH` (default: `-`) set the Storage-Path for a `sqlite` Database
- `DATABASE_GRAFANA_PASS` (default: `grafana`) the Database Password for Grafana
- `CARBON_HOST` (default: `-`) the carbon hostname to send internal Grafana metrics, can be identical with `GRAPHITE_HOST`
- `CARBON_PORT` (default: `2003`) the carbon Port
- `MEMCACHE_HOST` (default: `-`) the memcache Hostname to store Sessions
- `MEMCACHE_PORT` (default: `11211`) the memcache Port


## LDAP support

The environment variables for LDAP can be configured for 2 different reasons.:

### each environment variable is specified individually

- `LDAP_SERVER` (default: `-`) the LDAP server
- `LDAP_PORT` (default:  `389`) the LDAP Port
- `LDAP_BIND_DN` (default:  `-`) LDAP Bind DN
- `LDAP_BIND_PASSWORD` (default:  `-`) Bind Password
- `LDAP_BASE_DN` (default:  `-`) Base DN
- `LDAP_GROUP_DN` (default:  `-`) Group DN
- `LDAP_SEARCH_FILTER` (default:  `(cn=%s)`) LDAP search filter


### an environment variable summarizes everything as json

- `LDAP`(default: `-`) json formated configuration

```json
{
  "server":"${LDAP_SERVER}",
  "port":"${LDAP_PORT}",
  "bind_dn": "${LDAP_BIND_DN}",
  "bind_password": "${LDAP_BIND_PASSWORD}",
  "base_dn": "${LDAP_BASE_DN}",
  "group_dn": "${LDAP_GROUP_DN}",
  "search_filter": "${LDAP_SEARCH_FILTER}"
}
```

Both examples can be found in the `docker-compose` example.


# Grafana Plugins

- grafana plugins
  * grafana-clock-panel
  * grafana-piechart-panel
  * jdbranham-diagram-panel
  * mtanda-histogram-panel
  * btplc-trend-box-panel


# Ports

 - `3000`: grafana (plain)
