
FROM bodsch/docker-alpine-base:1701-02

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.8.1"

# 3000: grafana (plain)
EXPOSE 3000

ENV \
  GOPATH=/opt/go \
  GO15VENDOREXPERIMENT=0 \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel"

# ---------------------------------------------------------------------------------------

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add \
    build-base \
    nodejs \
    go \
    git \
    mercurial \
    netcat-openbsd \
    pwgen \
    jq \
    yajl-tools \
    mysql-client \
    sqlite && \
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  go run build.go latest && \
  echo "grafana setup .." && \
  go run build.go setup > /dev/null 2> /dev/null && \
  echo "grafana build .." && \
  go run build.go build > /dev/null 2> /dev/null && \
  npm config set loglevel silent && \
  npm update minimatch@3.0.2 && \
  npm update graceful-fs@4.0.0 && \
  npm update lodash@4.0.0 && \
  npm update fsevents@latest && \
  npm install   > /dev/null 2> /dev/null && \
  npm run build > /dev/null 2> /dev/null && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen         /usr/share/grafana/public && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \
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
    /usr/local/bin/phantomjs

COPY rootfs/ /

VOLUME [ "/usr/share/grafana/data" "/usr/share/grafana/public/dashboards" "/opt/grafana/dashboards" ]

WORKDIR /usr/share/grafana

CMD /opt/startup.sh

# EOF
