docker-grafana
==============

A Docker container for an (currently) actual Grafana Webinterface build from Source.

this container use phantomjs from [Overbryd](https://github.com/Overbryd/docker-phantomjs-alpine)

# Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-grafana.svg?branch)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-grafana.svg?branch)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-grafana.svg?branch)][travis]

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
| `ADMIN_PASSWORD`                   | -                    | change the default admin password                               |
|                                    |                      |                                                                 |
| `LDAP`                             | -                    | a json with LDAP configurations:                                |
|                                    |                      | `'{`                                                            |
|                                    |                      | `    "server":"${LDAP_SERVER}",`                                |
|                                    |                      | `    "port":"${LDAP_PORT}",`                                    |
|                                    |                      | `    "bind_dn": "${LDAP_BIND_DN}",`                             |
|                                    |                      | `    "bind_password": "${LDAP_BIND_PASSWORD}",`                 |
|                                    |                      | `    "base_dn": "${LDAP_BASE_DN}"`                              |
|                                    |                      | `    "group_dn": "${LDAP_GROUP_DN}",`                           |
|                                    |                      | `    "search_filter": "${LDAP_SEARCH_FILTER}"`                  |
|                                    |                      | `  }'`                                                          |
|                                    |                      |                                                                 |
| `USERS`                            | -                    | a json to create local users                                    |
|                                    |                      | `'[{`                                                           |
|                                    |                      | `    "username": "grafana",`                                    |
|                                    |                      | `    "password": "to-sec3t4y0u",`                               |
|                                    |                      | `    "email": "",`                                              |
|                                    |                      | `    "role": "Admin"`                                           |
|                                    |                      | `  },`                                                          |
|                                    |                      | `  {`                                                           |
|                                    |                      | `    "username": "foo",`                                        |
|                                    |                      | `    "password": "bar11bar",`                                   |
|                                    |                      | `    "email": "",`                                              |
|                                    |                      | `    "role": "Viewer"`                                          |
|                                    |                      | `}]'`                                                           |
|                                    |                      |                                                                 |
| `DATASOURCES`                      | -                    | a json to create some backend datasources.                      |
|                                    |                      | currently, i support only `influxdb` and `graphite`             |
|                                    |                      | `{`                                                             |
|                                    |                      | `  "influxdb": [`                                               |
|                                    |                      | `    {`                                                         |
|                                    |                      | `      "name": "telegraf",`                                     |
|                                    |                      | `      "host": "localhost",`                                    |
|                                    |                      | `      "database": "telegraf"`                                  |
|                                    |                      | `    },`                                                        |
|                                    |                      | `    {`                                                         |
|                                    |                      | `      "name": "influxdb",`                                     |
|                                    |                      | `      "host": "localhost",`                                    |
|                                    |                      | `      "port": 8086,`                                           |
|                                    |                      | `      "database": "influxdb",`                                 |
|                                    |                      | `      "default": false`                                        |
|                                    |                      | `      }`                                                       |
|                                    |                      | `  ],`                                                          |
|                                    |                      | `  "graphite": [`                                               |
|                                    |                      | `    {`                                                         |
|                                    |                      | `      "name": "graphite",`                                     |
|                                    |                      | `      "host": "localhost",`                                    |
|                                    |                      | `      "port": 2003,`                                           |
|                                    |                      | `      "database": "graphite",`                                 |
|                                    |                      | `      "default": true`                                         |
|                                    |                      | `    },`                                                        |
|                                    |                      | `    {`                                                         |
|                                    |                      | `      "name": "events",`                                       |
|                                    |                      | `      "host": "localhost",`                                    |
|                                    |                      | `      "port": 2003,`                                           |
|                                    |                      | `      "database": "events",`                                   |
|                                    |                      | `      "default": false`                                        |
|                                    |                      | `    }`                                                         |
|                                    |                      | `  ]`                                                           |
|                                    |                      | `}`                                                             |
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
