# docker-grafana

installs the Grafana Webinterface

## based on
alpine:latest

## includes
 - grafana v2.6.0

## Ports
 - 3000: grafana (plain)

### build
    ./build.sh

### run
    ./run.sh
or

    docker run -P \
      --env GRAPHITE_HOST=graphite.docker \
      --env GRAPHITE_PORT=8080 \
      --link=graphite:graphite.docker \
      --hostname=grafana \
      --name grafana \
      docker-grafana

