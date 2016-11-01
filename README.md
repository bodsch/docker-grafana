docker-grafana
==============

A Docker container for an (currently) actual Grafana Webinterface build from Source.


# Status

[![Build Status](https://travis-ci.org/bodsch/docker-grafana.svg?branch=master)](https://travis-ci.org/bodsch/docker-grafana)


# Build

Your can use the included Makefile.

To build the Container:
```make```

Starts the Container:
```make run```

Starts the Container with Login Shell:
```make shell```

Entering the Container:
```make exec```

Stop (but **not kill**):
```make stop```


# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-grafana/)


# supported Environment Vars

`ORGANISATION` to change the Organization Name (default: Docker)

`DATABASE_TYPE` to change the Type of Database. Supportet Types are mysql and sqlite3 (default: sqlite3)

`MYSQL_HOST` the MySQL Hostname

`MYSQL_PORT` the MySQL Port (default: 3306)

`MYSQL_ROOT_USER` MySQL Root Username (default: root)

`MYSQL_ROOT_PASS` MySQL Root Password

`GRAPHITE_HOST` the graphite Hostname to send internal Grafana metrics

`GRAPHITE_PORT` the graphite Port (default: 2003)

`GRAPHITE_HTTP_PORT` the graphite HTTP Port (default: 8080)

`MEMCACHE_HOST` the memcache Hostname to store Sessions

`MEMCACHE_PORT` the memcache Port (default: 11211)

`DATABASE_GRAFANA_PASS` the Database Password for Grafana (default: grafana)


# includes

 - grafana plugins
     * grafana-clock-panel
     * grafana-piechart-panel
     * jdbranham-diagram-panel
     * mtanda-histogram-panel


# Ports
 - 3000: grafana (plain)



