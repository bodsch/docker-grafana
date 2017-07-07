
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  GOLANG_VERSION="1.8.3" \
  NODEJS_VERSION="v8.1.3" \
  NPM_VERSION="5" \
  YARN_VERSION="latest" \
  GOPATH=/opt/go \
  GOROOT=/usr/lib/go \
  TERM=xterm \
  BUILD_DATE="2017-07-07" \
  GRAFANA_VERSION="5.0.0-pre1" \
  PHANTOMJS_VERSION="2.11" \
  CONFIG_FLAGS="" \
  DEL_PKGS="libstdc++" \
  RM_DIRS=/usr/include \
  GRAFANA_PLUGINS="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel" \
  APK_ADD="build-base ca-certificates curl jq git mysql-client netcat-openbsd  pwgen supervisor sqlite yajl-tools" \
  APK_BUILD_BASE="bash build-base git musl-dev openssl go linux-headers binutils-gold gpgme gnupg libstdc++"

EXPOSE 3000

LABEL \
  version="1707-27.4" \
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
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk update && \
  apk upgrade && \
  #
  # build packages
  #
  apk add ${APK_ADD} ${APK_BUILD_BASE} && \
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
  # build go-1.8
  #
  echo "build golang ${GOLANG_VERSION} from sources ..." && \
  export GOROOT_BOOTSTRAP="$(go env GOROOT)" && \
  export GOMAXPROCS=$(getconf _NPROCESSORS_ONLN) && \
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
    go && \
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
  #
  #
  gpg \
    --keyserver ha.pool.sks-keyservers.net \
    --recv-keys \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      56730D5401028683275BD23C23EFEFE93C4CFFFE \
      6A010C5166006599AA17F08146C2130DFD2497F5 && \
  #
  # build nodejs 8.1.3
  #
  echo "build nodejs ${NODEJS_VERSION} from sources ..." && \
  cd /tmp && \
  curl \
    --silent \
    --location \
    --retry 3 \
    --retry-delay 10 \
    --retry-connrefused \
    --output node-${NODEJS_VERSION}.tar.xz \
    https://nodejs.org/dist/${NODEJS_VERSION}/node-${NODEJS_VERSION}.tar.xz && \
  curl \
    --silent \
    --location \
    --retry 3 \
    --retry-delay 10 \
    --retry-connrefused \
    https://nodejs.org/dist/${NODEJS_VERSION}/SHASUMS256.txt.asc | gpg --batch --decrypt | \
    grep " node-${NODEJS_VERSION}.tar.xz\$" | sha256sum -c | grep . && \
  tar -xf node-${NODEJS_VERSION}.tar.xz && \
  cd node-${NODEJS_VERSION} && \
  ./configure --prefix=/usr ${CONFIG_FLAGS} && \
  make -j$(getconf _NPROCESSORS_ONLN) && \
  make install && \
  #
  # install npm 5
  #
  echo "install npm ${NPM_VERSION} ..." && \
  cd /tmp && \
  npm install -g npm@${NPM_VERSION} && \
  find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf && \

  if [ -n "$YARN_VERSION" ]; then \

    mkdir /usr/local/share/yarn && \

    curl \
      -sSL \
      -O https://yarnpkg.com/${YARN_VERSION}.tar.gz \
      -O https://yarnpkg.com/${YARN_VERSION}.tar.gz.asc && \

    gpg \
      --batch \
      --verify ${YARN_VERSION}.tar.gz.asc \
      ${YARN_VERSION}.tar.gz && \

    tar \
      -xf ${YARN_VERSION}.tar.gz \
      -C /usr/local/share/yarn \
      --strip 1 && \

    ln -s /usr/local/share/yarn/bin/yarn /usr/local/bin/ && \
    ln -s /usr/local/share/yarn/bin/yarnpkg /usr/local/bin/ ; \
  fi && \
  #
  # build and install grafana
  #
  echo "get grafana sources ..." && \
  go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  echo "grafana setup .." && \
  go run build.go setup  && \
  echo "grafana build .." && \
  go run build.go build && \
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
    /build \
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
