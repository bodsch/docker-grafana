
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="dl-cdn.alpinelinux.org" \
  ALPINE_VERSION="latest" \
  GOLANG_VERSION="1.8.2" \
  GOPATH=/opt/go \
  GOROOT=/usr/lib/go \
  TERM=xterm \
  BUILD_DATE="2017-05-24" \
  GRAFANA_VERSION="4.4.0-pre1" \
  PHANTOMJS_VERSION="2.11" \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel" \
  APK_BUILD_GO="ca-certificates bash curl gcc musl-dev openssl go" \
  APK_ADD="build-base ca-certificates curl jq git mysql-client netcat-openbsd nodejs-current pwgen supervisor sqlite yajl-tools" \
  APK_DEL="build-base git nodejs-current"

EXPOSE 3000

LABEL \
  version="1705-04" \
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
# https://golang.org/issue/14851
COPY build /build

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \

  #
  # build packages
  #
  for apk in ${APK_BUILD_GO} ; \
  do \
    apk --quiet --no-cache add --virtual build-deps ${apk} ; \
  done && \

  #
  # download and install phantomJS
  #
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/ && \

  #
  # build go-1.8
  #
  export GOROOT_BOOTSTRAP="$(go env GOROOT)" && \
  curl \
    --silent \
    --location \
    --retry 3 \
    --retry-delay 10 \
    --retry-connrefused \
    https://storage.googleapis.com/golang/go${GOLANG_VERSION}.src.tar.gz \
  | gunzip \
  | tar x -C /usr/local && \
  cd /usr/local/go/src && \
  patch -p2 -i /build/no-pic.patch && \
  ./make.bash && \
  apk --purge del \
    build-deps && \
  mkdir /usr/lib/go && \
  mv  /usr/local/go/bin       /usr/lib/go/ && \
  mv  /usr/local/go/lib       /usr/lib/go/ && \
  mv  /usr/local/go/pkg       /usr/lib/go/ && \
  mv  /usr/local/go/src       /usr/lib/go/ && \
  ln -s /usr/lib/go/bin/go    /usr/bin/go && \
  ln -s /usr/lib/go/bin/gofmt /usr/bin/gofmt && \
  rm -rf /usr/local/go && \
  unset GOROOT_BOOTSTRAP && \

  #
  # build and install grafana
  #
  for apk in ${APK_ADD} ; \
  do \
    apk --quiet --no-cache add ${apk} ; \
  done && \
  # build grafana
  #
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  echo "grafana setup .." && \
  go run build.go setup  && \
  echo "grafana build .." && \
  go run build.go build && \

  # build frontend
  #
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  /usr/bin/npm config set loglevel silent && \
  /usr/bin/npm install          && \
  /usr/bin/npm install -g yarn  && \
  yarn install --pure-lockfile --no-progress && \
  /usr/bin/npm run build && \

  # move all packages to the right place
  #
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen         /usr/share/grafana/public && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \

  # create needed directorys
  #
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor && \

  # install my favorite grafana plugins
  #
  for plugin in ${GRAFANA_PLUGINS} ; \
  do \
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done && \

  # and clean up
  #
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
    /build \
    /usr/lib/node_modules \
    /usr/lib/go \
    /usr/bin/go* \
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
