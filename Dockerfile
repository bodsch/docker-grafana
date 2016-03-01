FROM alpine:3.3

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.1.0"

#   80: grafana (nginx)
# 3000: grafana (plain)
EXPOSE 80 3000

ENV GRAFANA_VERSION=v2.6.0
ENV GOPATH=/go
# ---------------------------------------------------------------------------------------

RUN \
  apk add --update \
    build-base \
    nodejs \
    go \
    git \
    mercurial \
    sqlite \
    supervisor

RUN \
  PATH=$PATH:$GOPATH/bin \
  && mkdir -p $GOPATH/src/github.com/grafana && cd $GOPATH/src/github.com/grafana \
  && git clone https://github.com/grafana/grafana.git -b ${GRAFANA_VERSION} \
  && cd grafana \
  && go run build.go setup \
  && godep restore \
  && go build . \
  && npm install \
  && npm install -g grunt-cli \
  && cd $GOPATH/src/github.com/grafana/grafana/node_modules/karma-phantomjs-launcher/node_modules/phantomjs && node install \
  && cd $GOPATH/src/github.com/grafana/grafana && grunt

RUN \
  mkdir /var/log/supervisor && \
  mkdir -p /usr/share/grafana/bin/ && \
  cp -a $GOPATH/src/github.com/grafana/grafana/grafana /usr/share/grafana/bin/grafana-server && \
  mv $GOPATH/src/github.com/grafana/grafana/public_gen /usr/share/grafana/public && \
  cp -ra $GOPATH/src/github.com/grafana/grafana/conf /usr/share/grafana

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

VOLUME [ "/usr/share/grafana/data" ]

WORKDIR /usr/share/grafana

ENTRYPOINT [ "/opt/startup.sh" ]

