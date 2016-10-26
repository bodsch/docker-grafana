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

# includes

 - grafana plugins
     * grafana-clock-panel
     * grafana-piechart-panel
     * grafana-simple-json-datasource
     * raintank-worldping-app

# Ports
 - 3000: grafana (plain)



