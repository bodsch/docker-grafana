
FROM bodsch/docker-golang:1.8

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1705-03.dev"

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="v3.5" \
  TERM=xterm \
  BUILD_DATE="2017-05-13" \
  GRAFANA_VERSION="4.3.0-beta1" \
  GOPATH=/opt/go \
  GO15VENDOREXPERIMENT=0 \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel" \
  APK_ADD="build-base ca-certificates curl jq git mysql-client netcat-openbsd nodejs-current pwgen supervisor sqlite yajl-tools" \
  APK_DEL="build-base git nodejs-current"

EXPOSE 3000

LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.name="Grafana Docker Image" \
      org.label-schema.description="Inofficial Grafana Docker Image" \
      org.label-schema.url="https://www.grafana.com" \
      org.label-schema.vcs-url="https://github.com/bodsch/docker-grafana" \
      org.label-schema.vendor="Bodo Schulz" \
      org.label-schema.version=${GRAFANA_VERSION} \
      org.label-schema.schema-version="1.0" \
      com.microscaling.docker.dockerfile="/Dockerfile" \
      com.microscaling.license="GNU Lesser General Public License v3.0"

# ---------------------------------------------------------------------------------------

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  for apk in ${APK_ADD} ; \
  do \
    apk --quiet --no-cache add ${apk} ; \
  done && \
  # build grafana
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  echo "grafana setup .." && \
  go run build.go setup  && \
  echo "grafana build .." && \
  go run build.go build && \
  # build frontend
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  /usr/bin/npm config set loglevel silent && \
  /usr/bin/npm install          && \
  /usr/bin/npm install -g yarn  && \
  yarn install --pure-lockfile --no-progress && \
  /usr/bin/npm run build && \
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
  /usr/bin/npm uninstall -g grunt-cli && \
  /usr/bin/npm uninstall -g yarn && \
  /usr/bin/npm cache clear && \
  go clean -i -r && \
  for apk in ${APK_DEL} ; \
  do \
    apk del --quiet --purge ${apk} ; \
  done && \
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

CMD [ "/init/run.sh" ]
