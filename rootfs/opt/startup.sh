#!/bin/sh

initfile=/opt/run.init

GRAPHITE_HOST=${GRAPHITE_HOST:-localhost}
GRAPHITE_PORT=${GRAPHITE_PORT:-8080}

DATABASE_GRAFANA_TYPE=${DATABASE_GRAFANA_TYPE:-sqlite3}
DATABASE_GRAFANA_HOST=${DATABASE_GRAFANA_HOST:-""}
DATABASE_GRAFANA_PORT=${DATABASE_GRAFANA_PORT:-"3306"}
DATABASE_ROOT_USER=${DATABASE_ROOT_USER:-""}
DATABASE_ROOT_PASS=${DATABASE_ROOT_PASS:-""}

# wait for needed database
#while ! nc -z ${GRAPHITE_HOST} ${GRAPHITE_PORT}
#do
#  sleep 3s
#done

# must start initdb and do other jobs well
#sleep 10s

# -------------------------------------------------------------------------------------------------

initGrafana() {

   exec /usr/share/grafana/bin/grafana-server -homepath /usr/share/grafana  -config=/etc/grafana/grafana.ini &

   sleep 10s

   ps ax | grep grafana | grep -v grep

   sleep 5s

   kill -9 $(ps ax | grep grafana | grep -v grep | awk '{print $1}')
}

if [ ! -f "${initfile}" ]
then

  if [ "${DATABASE_GRAFANA_TYPE}" == "sqlite3" ]
  then

    if [ ! -f /usr/share/grafana/data/grafana.db ]
    then

      initGrafana

      sqlite3 -batch -bail -stats /usr/share/grafana/data/grafana.db "insert into 'data_source' ( org_id,version,type,name,access,url,basic_auth,is_default,json_data,created,updated,with_credentials ) values ( 1, 0, 'graphite','graphite','proxy','http://${GRAPHITE_HOST}:${GRAPHITE_PORT}',0,1,'{}',DateTime('now'),DateTime('now'),0 )"
    fi

  elif [ "${DATABASE_GRAFANA_TYPE}" == "mysql" ]
  then

    mysql_opts="--host=${DATABASE_GRAFANA_HOST} --user=${DATABASE_ROOT_USER} --password=${DATABASE_ROOT_PASS} --port=${DATABASE_GRAFANA_PORT}"

    if [ -z ${DATABASE_GRAFANA_HOST} ]
    then
      echo " [E] - i found no DATABASE_GRAFANA_HOST Parameter for type: '{DATABASE_GRAFANA_TYPE}'"
    else

      # wait for needed database
      while ! nc -z ${DATABASE_GRAFANA_HOST} ${DATABASE_GRAFANA_PORT}
      do
        sleep 3s
      done

      # must start initdb and do other jobs well
      sleep 10s

      # Passwords...
      DATABASE_GRAFANA_PASS=${DATABASE_GRAFANA_PASS:-$(pwgen -s 15 1)}

      (
        echo "--- create user 'grafana'@'%' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
        echo "CREATE DATABASE IF NOT EXISTS grafana;"
        echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON grafana.* TO 'grafana'@'%' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
        echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON grafana.* TO 'grafana'@'${DATABASE_GRAFANA_HOST}' IDENTIFIED BY '${DATABASE_GRAFANA_PASS}';"
        echo "FLUSH PRIVILEGES;"
      ) | mysql ${mysql_opts}

      INI="/etc/grafana/grafana.ini"

      sed -i 's|^type\ =\ sqlite3|type\ =\ mysql|'                               ${INI}
      sed -i 's|^host\ =|host\ = '${DATABASE_GRAFANA_HOST}':'${DATABASE_GRAFANA_PORT}'|g'           ${INI}
      sed -i 's|^name\ =|name\ = grafana|g'                              ${INI}
      sed -i 's|^user\ =|user\ = grafana|g'                              ${INI}
      sed -i 's|^password\ =|password\ = '${DATABASE_GRAFANA_PASS}'|g'   ${INI}

      initGrafana

      (
        echo "use grafana;"
        echo "INSERT IGNORE INTO data_source values ( 1, 1, 0, 'graphite', 'graphite', 'proxy', 'http://${GRAPHITE_HOST}:${GRAPHITE_PORT}', NULL, NULL, 'graphite', 0, NULL, NULL, 1, NULL, now(), now(), NULL );"
        echo "INSERT IGNORE INTO data_source values ( 2, 1, 0, 'graphite', 'tags', 'proxy', 'http://${GRAPHITE_HOST}:${GRAPHITE_PORT}', NULL, NULL, 'tags', 0, NULL, NULL, 0, NULL, now(), now(), NULL );"
        echo "--- insert IGNORE INTO into data_source ( org_id, version, type, name, access, url, database, basic_auth, is_default, created, updated, with_credentials ) values ( 1, 0, 'graphite','graphite','proxy','http://${GRAPHITE_HOST}:${GRAPHITE_PORT}','tags',0, 0, now(), now(),0 );"
        echo "update org set name = 'Docker' where id = 1";
      ) | mysql ${mysql_opts}

    fi
  fi

  touch ${initfile}

  echo -e "\n"
  echo " ==================================================================="
  echo " Grafana DatabaseUser 'grafana' password set to ${DATABASE_GRAFANA_PASS}"
  echo " You can use the Basic Auth Method to access the ReST-API:"
  echo "   curl http://admin:admin@localhost:3000/api/org"
  echo "   curl http://admin:admin@localhost:3000/api/datasources -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"localGraphite","type":"graphite","url":"http://192.168.99.100","access":"proxy","isDefault":false,"database":"asd"}'"
  echo " ==================================================================="
  echo ""

fi

echo -e "\n Starting Supervisor.\n  You can safely CTRL-C and the container will continue to run with or without the -d (daemon) option\n\n"

if [ -f /etc/supervisord.conf ]
then
  /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
fi


# EOF
