
FROM alpine:3.7

ENV \
  GOPATH=/opt/go \
  GOROOT=/usr/lib/go \
  GOMAXPROCS=4 \
  TERM=xterm \
  BUILD_DATE="2018-01-04" \
  BUILD_TYPE="git" \
  GRAFANA_VERSION="5.0.0-pre1" \
  PHANTOMJS_VERSION="2.11"

EXPOSE 3000

LABEL \
  version="1801" \
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

# ---------------------------------------------------------------------------------------

RUN \
  apk update --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --virtual .build-deps \
    g++ git go make python libuv nodejs nodejs-npm && \
  apk add --no-cache \
    bash ca-certificates curl jq mysql-client netcat-openbsd pwgen s6 sqlite yajl-tools && \
  # download and install phantomJS
  echo "get phantomjs ${PHANTOMJS_VERSION} from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/ && \
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
  go run build.go build  2> /dev/null && \
  unset GOMAXPROCS && \
  # build frontend
  echo "build frontend ..." && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  /usr/bin/npm config set loglevel silent && \
  /usr/bin/npm install          && \
  /usr/bin/npm install -g yarn  && \
  /usr/bin/yarn install --pure-lockfile --no-progress && \
  /usr/bin/npm run build && \
  # move all packages to the right place
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -a  ${GOPATH}/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  if [ -d public ] ; then \
    cp -ar ${GOPATH}/src/github.com/grafana/grafana/public           /usr/share/grafana/ ; \
  elif [ -d public_gen ] ; then \
    cp -ar ${GOPATH}/src/github.com/grafana/grafana/public_gen       /usr/share/grafana/public ; \
  fi && \
  # create needed directorys
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor && \
  # install my favorite grafana plugins
  echo "install grafana plugins ..." && \
  for plugin in grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel btplc-trend-box-panel ; \
  do \
     /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins install ${plugin} ; \
  done && \
  # and clean up
  go clean -i -r && \
  npm ls -gp --depth=0 | awk -F/node_modules/ '{print $2}' | grep -vE '^(npm|)$' | xargs -r npm -g rm && \
  apk del --quiet --purge .build-deps && \
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

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:3000 || exit 1

CMD [ "/init/run.sh" ]
