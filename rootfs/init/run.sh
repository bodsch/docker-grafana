#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

export WORK_DIR=/srv/grafana

ORGANISATION=${ORGANISATION:-"Docker"}

URL_PATH=${URL_PATH:-"/"}

DATABASE_TYPE=${DATABASE_TYPE:-sqlite3}

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}

SQLITE_PATH=${SQLITE_PATH:-""}

GRAPHITE_HOST=${GRAPHITE_HOST:-""}
GRAPHITE_PORT=${GRAPHITE_PORT:-2003}
GRAPHITE_HTTP_PORT=${GRAPHITE_HTTP_PORT:-8080}

CARBON_HOST=${CARBON_HOST:-""}
CARBON_PORT=${CARBON_PORT:-2003}

MEMCACHE_HOST=${MEMCACHE_HOST:-""}
MEMCACHE_PORT=${MEMCACHE_PORT:-"11211"}

DATABASE_GRAFANA_PASS=${DATABASE_GRAFANA_PASS:-grafana}

GRAFANA_CONFIG_FILE="/etc/grafana/grafana.ini"

DBA_TYPE=
DBA_HOST=
DBA_USER=
DBA_PASS=
DBA_NAME=

# -------------------------------------------------------------------------------------------------


prepare() {

  [ -d ${WORK_DIR} ] || mkdir -p ${WORK_DIR}

  if [ "${DATABASE_TYPE}" == "sqlite3" ]
  then
    DBA_TYPE=sqlite3
    MYSQL_PORT=

    i=$((${#SQLITE_PATH}-1))

    if ( [ ${i} -gt 1 ] && [ "${SQLITE_PATH:$i:1}" != "/" ] )
    then
      SQLITE_PATH="${SQLITE_PATH}/"
    fi

  elif [ "${DATABASE_TYPE}" == "mysql" ]
  then
    DBA_TYPE=mysql
    DBA_HOST="${MYSQL_HOST}"
    DBA_USER=grafana
    DBA_PASS=${DATABASE_GRAFANA_PASS}
    DBA_NAME=grafana
  fi

  if [ -z "${MEMCACHE_HOST}" ]
  then
    SESSION_PROVIDER="file"
    SESSION_CONFIG="sessions"
  else
    SESSION_PROVIDER="memcache"
    SESSION_CONFIG="${MEMCACHE_HOST}:${MEMCACHE_PORT}"
  fi

  if [ -z ${CARBON_HOST} ]
  then
    CARBON_PORT=
  else
    carbon_host="${CARBON_HOST}:${CARBON_PORT}"
  fi

  sed -i \
    -e 's|%DBA_TYPE%|'${DBA_TYPE}'|' \
    -e 's|%DBA_HOST%|'${DBA_HOST}:${MYSQL_PORT}'|g' \
    -e 's|%DBA_NAME%|'${DBA_NAME}'|g' \
    -e 's|%DBA_USER%|'${DBA_USER}'|g' \
    -e 's|%DBA_PASS%|'${DBA_PASS}'|g' \
    -e 's|%URL_PATH%|'${URL_PATH}'|g' \
    -e 's|%SESSION_PROVIDER%|'${SESSION_PROVIDER}'|g' \
    -e 's|%SESSION_CONFIG%|'${SESSION_CONFIG}'|g' \
    -e 's|%CARBON_HOST%|'${carbon_host}'|g' \
    -e 's|%ORGANISATION%|'${ORGANISATION}'|g' \
    -e 's|%SQLITE_PATH%|'${SQLITE_PATH}'|g' \
    ${GRAFANA_CONFIG_FILE}
}



startSupervisor() {

#   echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    echo " [E] no supervisord.conf found"
    exit 1
  fi
}

# -------------------------------------------------------------------------------------------------

run() {

  prepare

  . /init/database/mysql.sh
  . /init/configure_grafana.sh

  startSupervisor
}

run

# EOF
