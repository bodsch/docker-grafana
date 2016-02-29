
from debian:jessie

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.0.2"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

#   80: graphite: 80
#   81: grafana
# 2003: Carbon line receiver port
# 7002: Carbon cache query port
# 8125: Statsd UDP port
# 8126: Statsd Management port
expose  80 81 8125/udp 8126

# ---------------------------------------------------------------------------------------

run \
  apt-get -qqy update && \
  apt-get -qqy install --no-install-recommends \
    apt-transport-https \
    software-properties-common \
    curl \
    sudo && \
  echo "deb http://us.archive.ubuntu.com/ubuntu/ precise universe"      >> /etc/apt/sources.list && \
  echo "deb https://packagecloud.io/grafana/stable/debian/ wheezy main" >> /etc/apt/sources.list && \
  curl https://packagecloud.io/gpg.key | sudo apt-key add - && \
  apt-get -qqy update && \
  apt-get -qqy install --no-install-recommends \
    python-django-tagging python-simplejson python-memcache \
    python-ldap python-cairo python-django python-twisted   \
    python-pysqlite2 python-support python-pip gunicorn     \
    supervisor nginx-light git wget curl \
    grafana \
    sqlite3

run \
  mkdir /src && \
  git clone https://github.com/etsy/statsd.git /src/statsd && \
  cd /usr/local/src && \
  git clone https://github.com/graphite-project/graphite-web.git && \
  git clone https://github.com/graphite-project/carbon.git && \
  git clone https://github.com/graphite-project/whisper.git && \
  cd /usr/local/src/whisper && \
  git checkout master && \
  python setup.py install && \
  cd /usr/local/src/carbon && \
  git checkout 0.9.13-pre1 && \
  python setup.py install && \
  cd /usr/local/src/graphite-web && \
  git checkout 0.9.13-pre1 && \
  python check-dependencies.py && \
  python setup.py install

ADD rootfs/ /

run \
  chown -R www-data /opt/graphite/storage && \
  cd /opt/graphite/webapp/graphite && \
  python manage.py syncdb --noinput && \
  timeout 1 /usr/sbin/grafana-server -homepath /usr/share/grafana || true && \
  sqlite3 /usr/share/grafana/data/grafana.db "insert into data_source (org_id,version,type,name,access,url,basic_auth,is_default,json_data,created,updated,with_credentials) values (1,0,'graphite','graphite','proxy','http://localhost',0,1,'{}',DateTime('now'),DateTime('now'),0)"

VOLUME [ "/opt/graphite/storage/whisper", "/var/lib/log/supervisor" ]

cmd [ "/usr/bin/supervisord" ]
