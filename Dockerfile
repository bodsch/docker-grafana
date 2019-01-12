
FROM golang:1-stretch as builder

ARG VCS_REF
ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_TYPE=stable
ARG GRAFANA_VERSION

ENV \
  TERM=xterm-256color \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin' \
  GOPATH=/opt/go \
  GOMAXPROCS=4 \
  GOOS=linux \
  JOBS=4 \
  PHANTOMJS_VERSION="2.1.1"

# ---------------------------------------------------------------------------------------

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL4005
RUN \
  chsh -s /bin/bash && \
  ln -sf /bin/bash /bin/sh && \
  ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  ln -s  /etc/default /etc/sysconfig

RUN \
  apt-get update

RUN \
  apt-get dist-upgrade --assume-yes

# hadolint ignore=DL3008,DL3014,DL3015
RUN \
  apt-get install --assume-yes \
    apt-transport-https \
    bzip2 \
    lsb-release \
    ca-certificates \
    curl \
    gnupg \
    gcc \
    g++ \
    make \
    git \
    libuv1 \
    upx-ucl \
    libfontconfig1 \
    libfreetype6

RUN \
  curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
  echo 'deb https://deb.nodesource.com/node_10.x stretch main' > /etc/apt/sources.list.d/nodesource.list && \
  curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
  apt-get update

# hadolint ignore=DL3008,DL3014,DL3015
RUN \
  apt-get install --assume-yes \
    nodejs yarn

# download and install phantomJS
RUN \
  set -e && \
  export QT_QPA_PLATFORM= && \
  echo "get phantomjs \"${PHANTOMJS_VERSION}\" from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2" \
  | bunzip2 \
  | tar x -C /tmp/ && \
  mv "/tmp/phantomjs-${PHANTOMJS_VERSION}-linux-x86_64/bin/phantomjs" /usr/bin/

RUN \
  echo "export TZ=${TZ}"                            > /etc/profile.d/grafana.sh && \
  echo "export BUILD_DATE=${BUILD_DATE}"           >> /etc/profile.d/grafana.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"           >> /etc/profile.d/grafana.sh

## build and install grafana
RUN \
  go get github.com/grafana/grafana 2> /dev/null || true

WORKDIR ${GOPATH}/src/github.com/grafana/grafana

RUN \
  if [[ "${BUILD_TYPE}" = "stable" ]] ; then \
    echo "switch to stable Tag v${GRAFANA_VERSION}" && \
    git checkout "tags/v${GRAFANA_VERSION}" 2> /dev/null ; \
  fi && \
  GRAFANA_VERSION=$(git describe --tags --always | sed 's/^v//') && \
  echo "export GRAFANA_VERSION=${GRAFANA_VERSION}" >> /etc/profile.d/grafana.sh

RUN \
  go run build.go setup  2> /dev/null && \
  go run build.go build  2> /dev/null

# build frontend
RUN \
  /usr/bin/npm add -g npm@latest --no-progress && \
  /usr/bin/npm install           --no-progress && \
  /usr/bin/npm install -g yarn   --no-progress && \
  /usr/bin/yarn install --pure-lockfile --no-progress && \
  /usr/bin/yarn run build

  # sh -c 'pnmtopng "$1" > "$1.png"' _ {} \;

# move all packages to the right place
# hadolint ignore=SC2227
RUN \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -ar conf               /usr/share/grafana/ && \
  upx \
    --best \
    --no-progress \
    --no-color \
    -o/usr/share/grafana/bin/grafana-cli \
    bin/linux-amd64/grafana-cli && \
  upx \
    --best \
    --no-progress \
    --no-color \
    -o/usr/share/grafana/bin/grafana-server \
    bin/linux-amd64/grafana-server && \
  cp -rav tools /usr/share/grafana/ && \
  #find bin/ -type f -name grafana-cli    -exec sh -c 'upx -9 --no-progress "${1}"' _ {} \; && \
  #find bin/ -type f -name grafana-server -exec sh -c 'upx -9 --no-progress "${1}"' _ {} \; && \
  #find bin/ -type f -name grafana-cli    -exec sh -c 'cp  -av ${1} /usr/share/grafana/bin/' _ {} \; && \
  #find bin/ -type f -name grafana-server -exec sh -c 'cp  -av ${1} /usr/share/grafana/bin/' _ {} \; && \
  #find .    -type d -name tools          -exec sh -c 'cp -rav ${1} /usr/share/grafana/' _ {} \; && \
  if [[ -d public ]] ; then \
    cp -ar "${GOPATH}/src/github.com/grafana/grafana/public"           /usr/share/grafana/ ; \
  elif [[ -d public_gen ]] ; then \
    cp -ar "${GOPATH}/src/github.com/grafana/grafana/public_gen"       /usr/share/grafana/public ; \
  else \
    echo "missing 'public' directory" \
    exit 1 ; \
  fi

# install my favorite grafana plugins
RUN \
  echo "install my favorite grafana plugins ..." && \
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

# ---------------------------------------------------------------------------------------

FROM debian:9-slim

COPY --from=builder /etc/profile.d/grafana.sh /etc/profile.d/grafana.sh
COPY --from=builder /usr/share/grafana        /usr/share/grafana

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3014,DL3015
RUN \
  apt-get update && \
  [ -f /etc/profile.d/grafana.sh ] && . /etc/profile && \
  apt-get install --no-install-recommends --assume-yes \
    ca-certificates \
    curl \
    jq \
    mariadb-client \
    net-tools \
    netcat-openbsd \
    pwgen \
    procps \
    sqlite \
    yajl-tools \
    libfontconfig1 \
    && \
  cp "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  echo "${TZ}" > /etc/timezone && \
  mkdir /var/log/grafana && \
  echo 'Yes, do as I say!' | apt-get remove \
    e2fsprogs sysvinit-utils && \
  apt-get clean && \
  apt autoremove --assume-yes && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.cache \
    /root/.bundle 2> /dev/null

COPY rootfs/ /

VOLUME ["/usr/share/grafana/data", "/usr/share/grafana/public/dashboards", "/opt/grafana/dashboards"]

WORKDIR /usr/share/grafana

CMD ["/init/run.sh"]

EXPOSE 3000

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:3000 || exit 1

# ---------------------------------------------------------------------------------------

LABEL \
  version=${BUILD_VERSION} \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Grafana Docker Image" \
  org.label-schema.description="Inofficial Grafana Docker Image" \
  org.label-schema.url="https://www.grafana.com" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-grafana" \
  org.label-schema.vcs-ref=${VCS_REF} \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${GRAFANA_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="GNU Lesser General Public License v3.0"

# ---------------------------------------------------------------------------------------
