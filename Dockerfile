
FROM golang:1.8-alpine

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1703-03"

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="edge" \
  TERM=xterm \
  GOPATH=/opt/go \
  GO15VENDOREXPERIMENT=0 \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel"

EXPOSE 3000

# ---------------------------------------------------------------------------------------

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add \
    build-base \
    nodejs \
    git \
    mercurial \
    netcat-openbsd \
    pwgen \
    jq \
    yajl-tools \
    mysql-client \
    sqlite \
    supervisor

RUN \
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  echo "grafana setup .." && \
  go run build.go setup  && \
  echo "grafana build .." && \
  go run build.go build

RUN \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  npm config set loglevel silent && \
  npm install         > /dev/null 2> /dev/null && \
  npm install -g yarn > /dev/null 2> /dev/null && \
  yarn install --pure-lockfile --no-progress > /dev/null 2> /dev/null && \
  npm run build      > /dev/null 2> /dev/null

RUN \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen         /usr/share/grafana/public && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/

RUN \
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor && \
  for plugin in ${GRAFANA_PLUGINS} ; \
  do \
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done && \
  npm uninstall -g grunt-cli && \
  npm cache clear && \
  go clean -i -r && \
  apk del --purge \
    build-base \
    nodejs \
    go \
    git \
    bash \
    mercurial && \
  rm -rf \
    ${GOPATH} \
    /tmp/* \
    /var/cache/apk/* \
    /root/.n* \
    /root/.cache \
    /root/.config \
    /usr/local/go \
    /usr/local/bin/go-wrapper \
    /usr/lib/node_modules

COPY rootfs/ /

VOLUME [ "/usr/share/grafana/data" "/usr/share/grafana/public/dashboards" "/opt/grafana/dashboards" ]

WORKDIR /usr/share/grafana

#  CMD [ "/opt/startup.sh" ]


CMD [ "/bin/sh" ]