#!/bin/bash
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

  echo " ---------------------------------------------------"
  echo "   Grafana ${GRAFANA_VERSION} (${BUILD_TYPE}) build: ${BUILD_DATE}"
  echo " ---------------------------------------------------"
  echo ""

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
    carbon_host=
    ENABLE_METRICS="false"
  else
    carbon_host="${CARBON_HOST}:${CARBON_PORT}"
    ENABLE_METRICS="true"
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
    -e 's|%ENABLE_METRICS%|'${ENABLE_METRICS}'|g' \
    -e 's|%CARBON_HOST%|'${carbon_host}'|g' \
    -e 's|%ORGANISATION%|'${ORGANISATION}'|g' \
    -e 's|%SQLITE_PATH%|'${SQLITE_PATH}'|g' \
    ${GRAFANA_CONFIG_FILE}
}


start_grafana() {

  if [ "${DATABASE_TYPE}" == "mysql" ]
  then
    waitForDatabase
  fi

  echo " [i] start grafana-server in first time"

  exec /usr/share/grafana/bin/grafana-server \
    -homepath /usr/share/grafana \
    -config=${GRAFANA_CONFIG_FILE} \
    cfg:default.paths.logs=/var/log/grafana &

  if [ $? -eq 0 ]
  then
    echo " [i] successful ..."
  else
    echo " [E] result code: $?"
    exit 1
  fi

  echo " [i] wait for initalize grafana .. "

  sleep 2s

  RETRY=40

  # wait for grafana
  #
  until [ ${RETRY} -le 0 ]
  do
    grafana_up=$(netstat -tlnp | grep ":3000" | wc -l)

    [ ${grafana_up} -eq 1 ] && break

    echo " [i] waiting for grafana to come up"

    sleep 2s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [ $RETRY -le 0 ]
  then
    echo " [E] grafana is not successful started :("
    exit 1
  fi

  sleep 2s
}


kill_grafana() {

  grafana_pid=$(ps ax | grep grafana | grep -v grep | awk '{print $1}')

  if [ ! -z "${grafana_pid}" ]
  then
    kill -15 ${grafana_pid} > /dev/null 2> /dev/null

    sleep 2s
  fi
}


startSupervisor() {

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
  . /init/plugins.sh
  . /init/authentications.sh

  start_grafana

  ldap_authentication

  update_plugins

  kill_grafana

  startSupervisor
}

run

# EOF
