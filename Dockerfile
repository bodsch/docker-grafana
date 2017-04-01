
FROM bodsch/docker-golang:1.8

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1704-01"

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
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  apk --quiet --no-cache add \
    build-base \
    curl \
    nodejs \
    git \
    mercurial \
    netcat-openbsd \
    pwgen \
    jq \
    yajl-tools \
    mysql-client \
    sqlite \
    supervisor && \

  # build grafana
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  echo "grafana setup .." && \
  go run build.go setup  && \
  echo "grafana build .." && \
  go run build.go build && \

  # build frontend
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  npm config set loglevel silent && \
  npm install         > /dev/null 2> /dev/null && \
  npm install -g yarn > /dev/null 2> /dev/null && \
  yarn install --pure-lockfile --no-progress > /dev/null 2> /dev/null && \
  npm run build      > /dev/null 2> /dev/null && \

  # move all packages to the right place
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen         /usr/share/grafana/public && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \

  # create needed directorys
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor && \

  # install my favorite grafana plugins
  for plugin in ${GRAFANA_PLUGINS} ; \
  do \
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done && \

  # and clean up
  npm uninstall -g grunt-cli && \
  npm cache clear && \
  go clean -i -r && \
  apk del --purge \
    build-base \
    nodejs \
    git \
    bash \
    mercurial && \
  rm -rf \
    ${GOPATH} \
    /usr/lib/go \
    /usr/bin/go \
    /usr/bin/gofmt \
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

CMD [ "/opt/startup.sh" ]
