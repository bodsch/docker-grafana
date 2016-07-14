#!/bin/sh
#
#

if [ ${DEBUG} ]
then
  set -x
fi

WORK_DIR=${WORK_DIR:-/srv}
WORK_DIR=${WORK_DIR}/grafana

initfile=${WORK_DIR}/run.init

DATABASE_TYPE=${DATABASE_TYPE:-sqlite3}

MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}

GRAPHITE_HOST=${GRAPHITE_HOST:-graphite}
GRAPHITE_PORT=${GRAPHITE_PORT:-8080}

# -------------------------------------------------------------------------------------------------

waitForDatabase() {

  # wait for needed database
  while ! nc -z ${MYSQL_HOST} ${MYSQL_PORT}
  do
    sleep 3s
  done

  # must start initdb and do other jobs well
  echo " [i] wait for database for there initdb and do other jobs well"
  sleep 10s
}

prepare() {

  [ -d ${WORK_DIR} ] || mkdir -p ${WORK_DIR}
}

startGrafana() {

  exec /usr/share/grafana/bin/grafana-server -homepath /usr/share/grafana  -config=/etc/grafana/grafana.ini &

  sleep 10s
}

killGrafana() {

  grafana_pid=$(ps ax | grep grafana | grep -v grep | awk '{print $1}')

  kill -9 ${grafana_pid}

  sleep 2s
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

      curl ${curl_opts} \
        --request PUT \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data-binary "{\"name\":\"${name}\",\"type\":\"${type}\",\"access\":\"proxy\",\"url\":\"http://${GRAPHITE_HOST}:${GRAPHITE_PORT}\"}" \
        http://localhost:3000/api/datasources/${id}

    done
  else
    for i in graphite tags
    do
      cp /opt/grafana/datasource.tpl /opt/grafana/datasource-${i}.json

      sed -i \
        -e "s/%GRAPHITE_HOST%/${GRAPHITE_HOST}/" \
        -e "s/%GRAPHITE_PORT%/${GRAPHITE_PORT}/" \
        -e "s/%GRAPHITE_DATABASE%/${i}/" \
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

  local plugins="grafana-clock-panel grafana-piechart-panel grafana-simple-json-datasource raintank-worldping-app"

  for p in ${plugins}
  do
    /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins"  plugins install ${p}
  done

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

configureDatabase() {

  if [ ! -f ${initfile} ]
  then
    if [ "${DATABASE_TYPE}" == "sqlite3" ]
    then

      if [ ! -f /usr/share/grafana/data/grafana.db ]
      then

  #       startGrafana

        sqlite3 \
          -batch \
          -bail \
          -stats \
          /usr/share/grafana/data/grafana.db \
          "insert into 'data_source' ( org_id,version,type,name,access,url,basic_auth,is_default,json_data,created,updated,with_credentials ) values ( 1, 0, 'graphite','graphite','proxy','http://${GRAPHITE_HOST}:${GRAPHITE_PORT}',0,1,'{}',DateTime('now'),DateTime('now'),0 )"
      fi

    elif [ "${DATABASE_TYPE}" == "mysql" ]
    then

      mysql_opts="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"

      if [ -z ${MYSQL_HOST} ]
      then
        echo " [E] - i found no MYSQL_HOST Parameter for type: '{DATABASE_TYPE}'"
      else

        waitForDatabase

        # Passwords...
        DATABASE_GRAFANA_PASS=grafana # $(pwgen -s 15 1)

        (
          echo "--- create user 'grafana'@'%' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
          echo "CREATE DATABASE IF NOT EXISTS grafana;"
          echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON grafana.* TO 'grafana'@'%' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
          echo "--- GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON grafana.* TO 'grafana'@'${MYSQL_HOST}' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
          echo "FLUSH PRIVILEGES;"
        ) | mysql ${mysql_opts}

        CONFIG_FILE="/etc/grafana/grafana.ini"

        sed -i \
          -e 's|^type\ =\ sqlite3|type\ =\ mysql|' \
          -e 's|^host\ =\ .*|host\ = '${MYSQL_HOST}':'${MYSQL_PORT}'|g' \
          -e 's|^name\ =\ .*|name\ = grafana|g' \
          -e 's|^user\ =\ .*|user\ = grafana|g' \
          -e 's|^password\ =\ .*|password\ = '${DATABASE_GRAFANA_PASS}'|g' \
          ${CONFIG_FILE}
      fi
    fi

    touch ${initfile}
  fi
}

# -------------------------------------------------------------------------------------------------

run() {

  prepare
  configureDatabase
  startGrafana
  handleDataSources

  # insertPlugins

  killGrafana

  echo -e "\n"
  echo " ==================================================================="
  echo " Grafana DatabaseUser 'grafana' password set to '${DATABASE_GRAFANA_PASS}'"
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
