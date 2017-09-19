
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  GOPATH=/opt/go \
  GOROOT=/usr/lib/go \
  GOMAXPROCS=4 \
  TERM=xterm \
  BUILD_DATE="2017-09-19" \
  BUILD_TYPE="stable" \
  GRAFANA_VERSION="4.5.0" \
  PHANTOMJS_VERSION="2.11" \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel" \
  APK_ADD="bash ca-certificates curl jq mysql-client netcat-openbsd pwgen supervisor sqlite yajl-tools" \
  APK_BUILD_BASE="g++ git go make nodejs-current nodejs-current-npm"

EXPOSE 3000

LABEL \
  version="1709" \
  org.label-schema.build-date=${BUILD_DATE} \
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
  echo "http://${ALPINE_MIRROR}/alpine/edge/community"              >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} ${APK_BUILD_BASE} && \
  #
  # download and install phantomJS
  #
  echo "get phantomjs ${PHANTOMJS_VERSION} from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/ && \
  #
  # build and install grafana
  #
  echo "get grafana sources ..." && \
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  #
  # build stable packages
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${GRAFANA_VERSION}" && \
    git checkout tags/v${GRAFANA_VERSION} 2> /dev/null ; \
  fi && \
  #
  echo "grafana setup .." && \
  go run build.go setup  2> /dev/null && \
  echo "grafana build .." && \
  go run build.go build  2> /dev/null && \
  unset GOMAXPROCS && \
  #
  # build frontend
  #
  echo "build frontend ..." && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  /usr/bin/npm config set loglevel silent && \
  /usr/bin/npm install          && \
  /usr/bin/npm install -g yarn  && \
  /usr/bin/yarn install --pure-lockfile --no-progress && \
  /usr/bin/npm run build && \
  #
  # move all packages to the right place
  #
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen         /usr/share/grafana/public && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \
  #
  # create needed directorys
  #
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor && \
  #
  # install my favorite grafana plugins
  #
  echo "install grafana plugins ..." && \
  for plugin in ${GRAFANA_PLUGINS} ; \
  do \
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done && \
  #
  # and clean up
  #
  npm ls -gp --depth=0 | awk -F/node_modules/ '{print $2}' | grep -vE '^(npm|)$' | xargs -r npm -g rm && \
  go clean -i -r && \
  apk --quiet --purge del ${APK_BUILD_BASE} && \
  rm -rf \
    ${GOPATH} \
    /usr/lib/go \
    /usr/bin/go* \
    /usr/lib/node_modules \
    /tmp/* \
    /var/cache/apk/* \
    /root/.n* \
    /root/.cache \
    /root/.config \
    /usr/local/*

COPY rootfs/ /

VOLUME [ "/usr/share/grafana/data" "/usr/share/grafana/public/dashboards" "/opt/grafana/dashboards" ]

WORKDIR /usr/share/grafana

CMD [ "/init/run.sh" ]
