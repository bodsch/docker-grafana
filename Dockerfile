
FROM golang:1-alpine as builder

ARG BUILD_DATE
ARG BUILD_VERSION
ARG GRAFANA_VERSION

ENV \
  TERM=xterm \
  BUILD_TYPE="stable" \
  PHANTOMJS_VERSION="2.11" \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

RUN \
  apk update  --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add     --quiet \
    ca-certificates curl g++ git make python libuv nodejs nodejs-npm tzdata && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  echo "export TZ=${TZ}"                            > /etc/profile.d/grafana.sh && \
  echo "export BUILD_DATE=${BUILD_DATE}"           >> /etc/profile.d/grafana.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"           >> /etc/profile.d/grafana.sh && \
  echo "export GRAFANA_VERSION=${GRAFANA_VERSION}" >> /etc/profile.d/grafana.sh

RUN \
  # download and install phantomJS
  echo "get phantomjs ${PHANTOMJS_VERSION} from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/

RUN \
  export GOPATH=/opt/go && \
  export GOMAXPROCS=4 && \
  # build and install grafana
  echo "get grafana sources ..." && \
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  # build stable packages
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${GRAFANA_VERSION}" && \
    git checkout tags/v${GRAFANA_VERSION} 2> /dev/null ; \
  fi && \
  echo "grafana setup .." && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  go run build.go setup  2> /dev/null && \
  echo "grafana build .." && \
  go run build.go build  2> /dev/null

RUN \
  # build frontend
  echo "build frontend ..." && \
  export GOPATH=/opt/go && \
  export JOBS=4 && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  /usr/bin/npm add -g npm@latest --no-progress && \
  /usr/bin/npm install           --no-progress && \
  /usr/bin/npm install -g yarn   --no-progress && \
  /usr/bin/yarn install --pure-lockfile --no-progress && \
  /usr/bin/npm run build

RUN \
  export GOPATH=/opt/go && \
  # move all packages to the right place
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec cp -a {} /usr/share/grafana/bin/ \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec cp -a {} /usr/share/grafana/bin/ \; && \
  if [ -d public ] ; then \
    cp -ar ${GOPATH}/src/github.com/grafana/grafana/public           /usr/share/grafana/ ; \
  elif [ -d public_gen ] ; then \
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
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done

CMD [ "/bin/bash" ]

# ---------------------------------------------------------------------------------------

FROM alpine:3.8

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

RUN \
  apk --quiet --no-cache update && \
  if [ -f /etc/profile.d/grafana.sh ] ; then . /etc/profile.d/grafana.sh; fi && \
  apk add --quiet --no-cache \
    bash ca-certificates curl jq mariadb-client netcat-openbsd pwgen sqlite yajl-tools && \
  # create needed directorys
  mkdir /var/log/grafana && \
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
