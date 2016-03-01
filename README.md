# docker-grafana

installs the Grafana Webinterface

## based on
alpine:3.3

## includes
     grafana v2.6.0

### build
     ./build.sh

### run
      ./run.sh
or

      docker run -P --dns=172.17.0.1 --env GRAPHITE_HOST=graphite.docker GRAPHITE_PORT=8080 -link=graphite:graphite.docker --hostname=grafana --name grafana docker-grafana

## HINT
use the dynamic DNS Script taken from [blog.amartynov.ru](https://blog.amartynov.ru/archives/dnsmasq-docker-service-discovery) to resolve DNS between Containers