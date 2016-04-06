
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.2.0"

# 3000: grafana (plain)
EXPOSE 3000

ENV GOPATH=/opt/go
ENV GO15VENDOREXPERIMENT=0

# ---------------------------------------------------------------------------------------

RUN \
  apk update --quiet

RUN \
  apk add --quiet \
    build-base \
    nodejs \
    go \
    git \
    mercurial \
    netcat-openbsd \
    curl \
    pwgen \
    jq \
    yajl-tools \
    mysql-client \
    sqlite

RUN \
  go get github.com/grafana/grafana || true

RUN \
  cd $GOPATH/src/github.com/grafana/grafana && \
  go run build.go setup && \
  $GOPATH/bin/godep restore && \
  go run build.go build && \
  npm install && \
  npm install -g grunt-cli && \
  grunt

RUN \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -av  $GOPATH/src/github.com/grafana/grafana/bin/grafana-cli    /usr/share/grafana/bin/ && \
  cp -av  $GOPATH/src/github.com/grafana/grafana/bin/grafana-server /usr/share/grafana/bin/ && \
  cp -arv $GOPATH/src/github.com/grafana/grafana/public             /usr/share/grafana/ && \
  cp -arv $GOPATH/src/github.com/grafana/grafana/conf               /usr/share/grafana/

RUN \
  mkdir /var/log/grafana && \
  mkdir /var/log/supervisor

RUN \
  npm uninstall -g grunt-cli && \
  npm cache clear && \
  go clean -i -r && \
  apk del --purge \
    build-base \
    nodejs \
    go \
    git \
    mercurial && \
  rm -rf $GOPATH /tmp/* /var/cache/apk/* /root/.n* /usr/local/bin/phantomjs
  
ADD rootfs/ /

VOLUME [ "/usr/share/grafana/data" "/usr/share/grafana/public/dashboards" "/opt/grafana/dashboards" ]

WORKDIR /usr/share/grafana

ENTRYPOINT [ "/opt/startup.sh" ]

# EOF
