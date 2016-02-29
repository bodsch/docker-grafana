FROM alpine:3.3

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.1.0"

#   80: grafana (nginx)
# 3000: grafana (plain)
EXPOSE 80 3000

ENV GRAFANA_VERSION=v2.6.0

# ---------------------------------------------------------------------------------------

RUN \
#  export GRAFANA_VERSION=v2.6.0 \
    export GOPATH=/go \
    && PATH=$PATH:$GOPATH/bin \
    && apk add --update build-base nodejs go git mercurial sqlite \
    && mkdir -p /go/src/github.com/grafana && cd /go/src/github.com/grafana \
    && git clone https://github.com/grafana/grafana.git -b ${GRAFANA_VERSION} \
    && cd grafana \
    && go run build.go setup \
    && godep restore \
    && go build . \
    && npm install \
    && npm install -g grunt-cli \
    && cd /go/src/github.com/grafana/grafana/node_modules/karma-phantomjs-launcher/node_modules/phantomjs && node install \
    && cd /go/src/github.com/grafana/grafana && grunt \
    && npm uninstall -g grunt-cli \
    && npm cache clear \
    && mkdir -p /usr/share/grafana/bin/ \
    && cp -a /go/src/github.com/grafana/grafana/grafana /usr/share/grafana/bin/grafana-server \
    && cp -ra /go/src/github.com/grafana/grafana/public_gen /usr/share/grafana \
    && mv /usr/share/grafana/public_gen /usr/share/grafana/public \
    && cp -ra /go/src/github.com/grafana/grafana/conf /usr/share/grafana \
    && go clean -i -r \
    && apk del --purge build-base nodejs go git mercurial \
    && rm -rf /go /tmp/* /var/cache/apk/* /root/.n* /usr/local/bin/phantomjs

# nachläufiger prozess ..
#run \
#  sleep 1s && \
#  /usr/share/grafana/bin/grafana-server -homepath /usr/share/grafana && \
#  sqlite3 /usr/share/grafana/data/grafana.db "insert into data_source (org_id,version,type,name,access,url,basic_auth,is_default,json_data,created,updated,with_credentials) values (1,0,'graphite','graphite','proxy','http://localhost',0,1,'{}',DateTime('now'),DateTime('now'),0)"

#ADD rootfs/ /

VOLUME [ "/usr/share/grafana/data" ]

WORKDIR [ "/usr/share/grafana" ]
CMD ["/usr/share/grafana/bin/grafana-server"]

# CMD [ "/bin/sh" ]
# CMD     ["/usr/bin/supervisord"]
