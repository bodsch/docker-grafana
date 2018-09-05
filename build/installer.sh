#!/bin/sh

set -e

export GOPATH=/opt/go
export GOMAXPROCS=4
export GOOS=linux
export JOBS=4
export PHANTOMJS_VERSION="2.11"

echo "stage #1"
  apk update  --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add     --quiet \
    ca-certificates curl g++ git make python libuv nodejs nodejs-npm upx tzdata && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  echo "export TZ=${TZ}"                            > /etc/profile.d/grafana.sh && \
  echo "export BUILD_DATE=${BUILD_DATE}"           >> /etc/profile.d/grafana.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"           >> /etc/profile.d/grafana.sh

# download and install phantomJS
echo "stage #2"
  echo "get phantomjs ${PHANTOMJS_VERSION} from external ressources ..." && \
  curl \
    --silent \
    --location \
    --retry 3 \
    https://github.com/Overbryd/docker-phantomjs-alpine/releases/download/${PHANTOMJS_VERSION}/phantomjs-alpine-x86_64.tar.bz2 \
  | bunzip2 \
  | tar x -C / && \
  ln -s /phantomjs/phantomjs /usr/bin/

# get grafana sources
echo "stage #3"
#  export GOPATH=/opt/go && \
  time go get github.com/grafana/grafana || true && \
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  # build stable packages
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${GRAFANA_VERSION}" && \
    git checkout tags/v${GRAFANA_VERSION} 2> /dev/null ; \
  fi && \
  GRAFANA_VERSION=$(git describe --tags --always | sed 's/^v//') && \
  echo "export GRAFANA_VERSION=${GRAFANA_VERSION}" >> /etc/profile.d/grafana.sh

# build and install grafana
echo "stage #4"
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  time go run build.go setup  2> /dev/null && \
  time go run build.go build  2> /dev/null

# build frontend
echo "stage #5"
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  time /usr/bin/npm add -g npm@latest --no-progress && \
  time /usr/bin/npm install           --no-progress && \
  time /usr/bin/npm install -g yarn   --no-progress && \
  time /usr/bin/yarn install --pure-lockfile --no-progress && \
  time /usr/bin/yarn run build

# move all packages to the right place
echo "stage #6"
  cd ${GOPATH}/src/github.com/grafana/grafana && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -ar ${GOPATH}/src/github.com/grafana/grafana/conf               /usr/share/grafana/ && \
  #find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec ls -lh {} \; && \
  #find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec ls -lh {} \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec upx -q -9 --no-progress {} > /dev/null \; && \
  find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec upx -q -9 --no-progress {} > /dev/null \; && \
  #find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-cli    -exec ls -lh {} \; && \
  #find ${GOPATH}/src/github.com/grafana/grafana/bin/ -type f -name grafana-server -exec ls -lh {} \; && \
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

if [[ "${SKIP_PLUGINS}" != "true" ]]
then
  # install my favorite grafana plugins
  echo "stage #7"
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
fi
