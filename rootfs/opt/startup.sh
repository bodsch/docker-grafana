#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

WORK_DIR=${WORK_DIR:-/srv}
WORK_DIR=${WORK_DIR}/grafana

initfile=${WORK_DIR}/database.init

ORGANISATION=${ORGANISATION:-"Docker"}

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

waitForDatabase() {

  if [ "${DATABASE_TYPE}" == "mysql" ]
  then

    local mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT} --silent --batch --skip-column-names"

    # wait for needed database
    while ! nc -z ${MYSQL_HOST} ${MYSQL_PORT}
    do
      sleep 5s
    done

    # must start initdb and do other jobs well
    echo " [i] wait for database for there initdb and do other jobs well"

    until mysql ${mysql_opts} --execute="select 1 from mysql.user limit 1" > /dev/null
    do
      echo " . "
      sleep 3s
    done

  fi

}


prepare() {

  [ -d ${WORK_DIR} ] || mkdir -p ${WORK_DIR}

  if [ "${DATABASE_TYPE}" == "sqlite3" ]
  then
    DBA_TYPE=sqlite3

  elif [ "${DATABASE_TYPE}" == "mysql" ]
  then
    DBA_TYPE=mysql
    DBA_HOST="${MYSQL_HOST}:${MYSQL_PORT}"
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
    -e 's|%DBA_HOST%|'${DBA_HOST}'|g' \
    -e 's|%DBA_NAME%|'${DBA_NAME}'|g' \
    -e 's|%DBA_USER%|'${DBA_USER}'|g' \
    -e 's|%DBA_PASS%|'${DBA_PASS}'|g' \
    -e 's|%SESSION_PROVIDER%|'${SESSION_PROVIDER}'|g' \
    -e 's|%SESSION_CONFIG%|'${SESSION_CONFIG}'|g' \
    -e 's|%CARBON_HOST%|'${carbon_host}'|g' \
    ${GRAFANA_CONFIG_FILE}
}


createDatabase() {

  result=999

  if [ ! -f ${initfile} ]
  then
    if [ "${DATABASE_TYPE}" == "sqlite3" ]
    then

      if [ ! -f /usr/share/grafana/data/grafana.db ]
      then
        :
      fi

    elif [ "${DATABASE_TYPE}" == "mysql" ]
    then

      local mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"

      if [ -z ${MYSQL_HOST} ]
      then
        echo " [E] - i found no MYSQL_HOST Parameter for type: '{DATABASE_TYPE}'"
      else

        waitForDatabase

        (
          echo "--- create user 'grafana'@'%' IDENTIFIED BY '${DBA_PASS}';"
          echo "CREATE DATABASE IF NOT EXISTS grafana;"
          echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON grafana.* TO 'grafana'@'%' IDENTIFIED BY '${DBA_PASS}';"
          echo "FLUSH PRIVILEGES;"
        ) | mysql ${mysql_opts}

        result=$?
      fi
    fi

    if [ ${result} -eq 0 ]
    then
      touch ${initfile}
    fi
  fi

}

startGrafana() {

  waitForDatabase

  exec /usr/share/grafana/bin/grafana-server -homepath /usr/share/grafana  -config=${GRAFANA_CONFIG_FILE} cfg:default.paths.logs=/var/log/grafana &

  if [ $? -eq 0 ]
  then
    echo "successful ..."
  else
    echo "result code: $?"
  fi

  echo "wait for initalize grafana .. "

  while ! nc -z localhost 3000
  do
    sleep 5s
  done

  sleep 5s

  echo "done"
}


killGrafana() {

  grafana_pid=$(ps ax | grep grafana | grep -v grep | awk '{print $1}')

  if [ ! -z "${grafana_pid}" ]
  then
    kill -9 ${grafana_pid}

    sleep 2s
  fi
}


handleOrganisation() {

  curl_opts="--silent --user admin:admin"

  data=$(curl ${curl_opts} http://localhost:3000/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  if [ "${name}" != "${ORGANISATION}"  ]
  then
    curl ${curl_opts} \
      --request PUT \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --data-binary "{\"name\":\"${ORGANISATION}\"}" \
      http://localhost:3000/api/org
  fi
}


handleDataSources() {

  curl_opts="--silent --user admin:admin"

  datasource_count=$(curl ${curl_opts} 'http://localhost:3000/api/datasources' | json_reformat | grep -c "id")

  if [ ${datasource_count} -gt 0 ]
  then
    for c in $(seq 1 ${datasource_count})
    do
      # get type and id - we need it later!
      data=$(curl ${curl_opts} http://localhost:3000/api/datasources/${c})

      id=$(echo ${data} | jq  --raw-output '.id')
      name=$(echo ${data} | jq --raw-output '.name')
      type=$(echo ${data} | jq --raw-output '.type')
      default=$(echo ${data} | jq --raw-output '.isDefault')

      curl ${curl_opts} \
        --request PUT \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data-binary "{\"name\":\"${name}\",\"type\":\"${type}\",\"isDefault\":${default},\"access\":\"proxy\",\"url\":\"http://${GRAPHITE_HOST}:${GRAPHITE_HTTP_PORT}\"}" \
        http://localhost:3000/api/datasources/${id}

    done
  else
    for i in graphite events
    do
      cp /opt/grafana/datasource.tpl /opt/grafana/datasource-${i}.json

      if [ "${i}" == "graphite" ]
      then
        DATABASE_DEFAULT="true"
      else
        DATABASE_DEFAULT="false"
      fi

      sed -i \
        -e "s/%GRAPHITE_HOST%/${GRAPHITE_HOST}/" \
        -e "s/%GRAPHITE_PORT%/${GRAPHITE_HTTP_PORT}/" \
        -e "s/%GRAPHITE_DATABASE%/${i}/" \
        -e "s/%DATABASE_DEFAULT%/${DATABASE_DEFAULT}/" \
        /opt/grafana/datasource-${i}.json

      curl ${curl_opts} \
        --request POST \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data-binary @/opt/grafana/datasource-${i}.json \
        http://localhost:3000/api/datasources/
    done
  fi

  sleep 2s
}


insertPlugins() {

  local plugins="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel"

  for p in ${plugins}
  do
    /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins"  plugins install ${p}
  done

}


updatePlugin() {

  /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins upgrade-all

}


startSupervisor() {

  echo -e "\n Starting Supervisor.\n\n"

  if [ -f /etc/supervisord.conf ]
  then
    /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
  else
    exec /bin/sh
  fi
}

# -------------------------------------------------------------------------------------------------

run() {

  prepare
  createDatabase
  startGrafana

  handleOrganisation
  handleDataSources

  # insertPlugins
  updatePlugin

  killGrafana

  echo -e "\n"
  echo " ==================================================================="
  echo " Grafana Database User 'grafana' password set to '${DBA_PASS}'"
  echo " Grafana Organisation set to '${ORGANISATION}'"
  echo ""
  echo " You can use the Basic Auth Method to access the ReST-API:"
  echo "   curl http://admin:admin@localhost:3000/api/org"
  echo "   curl http://admin:admin@localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' \\"
  echo "      --data-binary '{"name":"localGraphite","type":"graphite","url":"http://192.168.99.100","access":"proxy","isDefault":false,"database":"asd"}'"
  echo "   curl -X GET http://admin:admin@localhost:3000/api/search?query= | json_reformat"
  echo "   curl -X DELETE http://admin:admin@localhost:3000/api/dashboards/db/${DASHBOARD}"
  echo " ==================================================================="
  echo ""

  startSupervisor
}

run

# EOF
