
FROM golang:1-alpine as builder

ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_TYPE=stable
ARG GRAFANA_VERSION

ENV \
  TERM=xterm-256color \
  TZ='Europe/Berlin' \
  GOPATH=/opt/go \
  GOMAXPROCS=4 \
  GOOS=linux \
  JOBS=4 \
  PHANTOMJS_VERSION="2.11"

# ---------------------------------------------------------------------------------------
#ADD build /build

#RUN \
#  /build/installer.sh


RUN \
  apk update  --quiet && \
  apk upgrade --quiet && \
  apk add     --quiet \
    ca-certificates curl g++ git make python libuv nodejs nodejs-npm upx && \
  echo "export TZ=${TZ}"                            > /etc/profile.d/grafana.sh && \
  echo "export BUILD_DATE=${BUILD_DATE}"           >> /etc/profile.d/grafana.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"           >> /etc/profile.d/grafana.sh

# download and install phantomJS
RUN \
  echo "get phantomjs ${PHANTOMJS_VERSION} from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/

# build and install grafana
RUN \
  time go get github.com/grafana/grafana 2> /dev/null || true

RUN \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  if [[ "${BUILD_TYPE}" = "stable" ]] ; then \
    echo "switch to stable Tag v${GRAFANA_VERSION}" && \
    git checkout tags/v${GRAFANA_VERSION} 2> /dev/null ; \
  fi && \
  GRAFANA_VERSION=$(git describe --tags --always | sed 's/^v//') && \
  echo "export GRAFANA_VERSION=${GRAFANA_VERSION}" >> /etc/profile.d/grafana.sh

RUN \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  time go run build.go setup  2> /dev/null && \
  time go run build.go build  2> /dev/null

# build frontend
RUN \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  time /usr/bin/npm add -g npm@latest --no-progress && \
  time /usr/bin/npm install           --no-progress && \
  time /usr/bin/npm install -g yarn   --no-progress && \
  time /usr/bin/yarn install --pure-lockfile --no-progress && \
  time /usr/bin/yarn run build

# move all packages to the right place
RUN \
  export GOPATH=/opt/go && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -ar conf               /usr/share/grafana/ && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec upx -q -9 --no-progress {} > /dev/null \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec upx -q -9 --no-progress {} > /dev/null \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec cp -a {} /usr/share/grafana/bin/ \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec cp -a {} /usr/share/grafana/bin/ \; && \
  if [[ -d public ]] ; then \
    cp -ar ${GOPATH}/src/github.com/grafana/grafana/public           /usr/share/grafana/ ; \
  elif [[ -d public_gen ]] ; then \
    cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen       /usr/share/grafana/public ; \
  else \
    echo "missing 'public' directory" \
    exit 1 ; \
  fi

RUN \
  # install my favorite grafana plugins
  echo "install grafana plugins ..." && \
  for plugin in \
    blackmirror1-statusbygroup-panel \
    btplc-trend-box-panel \
    digiapulssi-breadcrumb-panel \
    grafana-clock-panel \
    grafana-piechart-panel \
    jdbranham-diagram-panel \
    michaeldmoore-annunciator-panel \
    mtanda-histogram-panel \
    natel-discrete-panel \
    neocat-cal-heatmap-panel \
    vonage-status-panel \
    petrslavotinek-carpetplot-panel \
    snuids-radar-panel \
    zuburqan-parity-report-panel ; \
  do \
     /usr/share/grafana/bin/grafana-cli \
      --pluginsDir "/usr/share/grafana/data/plugins" \
      plugins \
      install ${plugin} ; \
  done

CMD [ "/bin/bash" ]

# ---------------------------------------------------------------------------------------

FROM alpine:3.8

RUN \
  apk --quiet --no-cache update && \
  [[ -f /etc/profile.d/grafana.sh ]] && . /etc/profile.d/grafana.sh && \
  apk add --no-cache --quiet --virtual .build-deps \
    tzdata && \
  apk add --quiet --no-cache \
    bash ca-certificates curl jq mariadb-client netcat-openbsd pwgen sqlite yajl-tools && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  mkdir /var/log/grafana && \
  apk del --quiet --purge .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY --from=builder /etc/profile.d/grafana.sh /etc/profile.d/grafana.sh
COPY --from=builder /usr/share/grafana /usr/share/grafana
COPY --from=builder /usr/bin/phantomjs /usr/bin/phantomjs

COPY rootfs/ /

VOLUME [ "/usr/share/grafana/data" "/usr/share/grafana/public/dashboards" "/opt/grafana/dashboards" ]

WORKDIR /usr/share/grafana

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:3000 || exit 1

CMD [ "/init/run.sh" ]

EXPOSE 3000

LABEL \
  version=${BUILD_VERSION} \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
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
