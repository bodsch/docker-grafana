#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

ORGANISATION=${ORGANISATION:-"Docker"}

URL_PATH=${URL_PATH:-"/grafana/"}

DATABASE_TYPE=${DATABASE_TYPE:-sqlite3}

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}

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

  if [ "${DATABASE_TYPE}" == "sqlite3" ]
  then
    DBA_TYPE=sqlite3

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

#   echo -e "\n"
#   echo " ==================================================================="
#   echo " Grafana Database User 'grafana' password set to '${DBA_PASS}'"
#   echo " Grafana Organisation set to '${ORGANISATION}'"
#   echo ""
#   echo " You can use the Basic Auth Method to access the ReST-API:"
#   echo "   curl http://admin:admin@localhost:3000/api/org"
#   echo "   curl http://admin:admin@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' \\"
#   echo "      --data-binary '{"name":"localGraphite","type":"graphite","url":"http://192.168.99.100","access":"proxy","isDefault":false,"database":"asd"}'"
#   echo "   curl -X GET http://admin:admin@localhost:3000/api/search?query= | json_reformat"
#   echo "   curl -X DELETE http://admin:admin@localhost:3000/api/dashboards/db/${DASHBOARD}"
#   echo " ==================================================================="
#   echo ""

  startSupervisor
}

run

# EOF
