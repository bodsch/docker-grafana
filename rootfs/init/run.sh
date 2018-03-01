#!/bin/bash
#
#

[[ ${DEBUG} ]] && set -x

[[ -f /etc/enviroment ]] && . /etc/enviroment

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

. /init/output.sh

# -------------------------------------------------------------------------------------------------

prepare() {

  log_info "---------------------------------------------------"
  log_info "  Grafana ${GRAFANA_VERSION} (${BUILD_TYPE}) build: ${BUILD_DATE}"
  log_info "---------------------------------------------------"

  [[ -d ${WORK_DIR} ]] || mkdir -p ${WORK_DIR}

  if [[ "${DATABASE_TYPE}" == "sqlite3" ]]
  then
    DBA_TYPE=sqlite3
    MYSQL_PORT=

    i=$((${#SQLITE_PATH}-1))

    if ( [[ ${i} -gt 1 ]] && [[ "${SQLITE_PATH:$i:1}" != "/" ]] )
    then
      SQLITE_PATH="${SQLITE_PATH}/"
    fi

  elif [[ "${DATABASE_TYPE}" == "mysql" ]]
  then
    DBA_TYPE=mysql
    DBA_HOST="${MYSQL_HOST}"
    DBA_USER=grafana
    DBA_PASS=${DATABASE_GRAFANA_PASS}
    DBA_NAME=grafana

    dba_host="${DBA_HOST}:${MYSQL_PORT}"
  fi

  # default session handling
  #
  SESSION_PROVIDER="file"
  SESSION_CONFIG="sessions"

  if [[ ! -z "${MEMCACHE_HOST}" ]]
  then
    SESSION_PROVIDER="memcache"
    SESSION_CONFIG="${MEMCACHE_HOST}:${MEMCACHE_PORT}"
  fi

  # default metrics handling
  #
  carbon_host=
  ENABLE_METRICS="false"

  if [[ ! -z ${CARBON_HOST} ]]
  then
    carbon_host="${CARBON_HOST}:${CARBON_PORT}"
    ENABLE_METRICS="true"
  fi

  sed -i \
    -e 's|%DBA_TYPE%|'${DBA_TYPE}'|' \
    -e 's|%DBA_HOST%|'${dba_host}'|g' \
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

  [[ "${DATABASE_TYPE}" == "mysql" ]] && waitForDatabase

  log_info "start grafana-server for the first time to create database schemas and update plugins"

  exec /usr/share/grafana/bin/grafana-server \
    -homepath /usr/share/grafana \
    -config=${GRAFANA_CONFIG_FILE} \
    cfg:default.server.http_addr=127.0.0.1 \
    cfg:default.paths.logs=/var/log/grafana &

  if [[ $? -gt 0 ]]
  then
    log_error "result code: $?"
    exit 1
  fi

  sleep 2s

  RETRY=40

  # wait for grafana
  #
  until [[ ${RETRY} -le 0 ]]
  do
    grafana_up=$(netstat -tlnp | grep ":3000" | wc -l)

    [[ ${grafana_up} -eq 1 ]] && break

    log_info "waiting for grafana to come up"

    sleep 4s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ ${RETRY} -le 0 ]]
  then
    log_error "grafana is not successful started :("
    exit 1
  fi

  sleep 2s
}


kill_grafana() {

  grafana_pid=$(ps ax | grep grafana | grep -v grep | awk '{print $1}')

  if [[ ! -z "${grafana_pid}" ]]
  then
    kill -15 ${grafana_pid} > /dev/null 2> /dev/null

    sleep 2s
  fi
}

update_organisation() {

  log_info "updating organistation to '${ORGANISATION}'"

  curl_opts="--silent --user admin:admin"

  data=$(curl ${curl_opts} http://localhost:3000/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  if [[ "${name}" != "${ORGANISATION}" ]]
  then
    data=$(curl \
      ${curl_opts} \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --request PUT \
      --data-binary "{\"name\":\"${ORGANISATION}\"}" \
      http://localhost:3000/api/org)
  fi
}

# -------------------------------------------------------------------------------------------------

run() {

  prepare

  . /init/database.sh
  . /init/organisation.sh
  . /init/plugins.sh
  . /init/authentications.sh

  start_grafana

  update_organisation
  ldap_authentication
  update_plugins

  kill_grafana

  log_info "start init process ..."

  /usr/share/grafana/bin/grafana-server \
    -homepath=/usr/share/grafana \
    -pidfile=/tmp/grafana.pid \
    -config=/etc/grafana/grafana.ini \
    cfg:default.paths.data=/usr/share/grafana \
    cfg:default.paths.logs=/var/log/grafana
}

run

# EOF
