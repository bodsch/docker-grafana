#!/bin/sh

set -x

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

if [ ! -f "${initfile}" ]
then

  if [ "${DATABASE_GRAFANA_TYPE}" == "sqlite3" ]
  then

    if [ ! -f /usr/share/grafana/data/grafana.db ]
    then
      exec /usr/share/grafana/bin/grafana-server -homepath /usr/share/grafana & 1> /dev/null
      sleep 5s

      ps ax | grep grafana | grep -v grep

      sleep 5s

      kill -9 $(ps ax | grep grafana | grep -v grep | awk '{print $1}')

      sqlite3 -batch -bail -stats /usr/share/grafana/data/grafana.db "insert into 'data_source' ( org_id,version,type,name,access,url,basic_auth,is_default,json_data,created,updated,with_credentials ) values ( 1, 0, 'graphite','graphite','proxy','http://${GRAPHITE_HOST}:${GRAPHITE_PORT}',0,1,'{}',DateTime('now'),DateTime('now'),0 )"
      sleep 2s

      sqlite3 -batch -bail -stats /usr/share/grafana/data/grafana.db ".dump data_source"

    fi

  elif [ "${DATABASE_GRAFANA_TYPE}" == "mysql" ]
  then

    mysql_opts="--host=${DATABASE_GRAFANA_HOST} --user=${DATABASE_ROOT_USER} --password=${DATABASE_ROOT_PASS} --port=${DATABASE_GRAFANA_PORT}"

    if [ -z ${GRAFANA_DATABASE_HOST} ]
    then
      echo " [E] - i found no GRAFANA_DATABASE_HOST Parameter for type: '{GRAFANA_DATABASE_TYPE}'"
    else

      # wait for needed database
      while ! nc -z ${DATABASE_GRAFANA_HOST} ${DATABASE_GRAFANA_PORT}
      do
        sleep 3s
      done

      # must start initdb and do other jobs well
      sleep 10s

      # Passwords...
      GRAFANA_DATABASE_PASS=${GRAFANA_DATABASE_PASS:-$(pwgen -s 15 1)}

      (
        echo "--- create user 'grafana'@'%' IDENTIFIED BY '${GRAFANA_DATABASE_PASS}';"
        echo "CREATE DATABASE IF NOT EXISTS grafana;"
        echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON grafana.* TO 'grafana'@'%' IDENTIFIED BY '${GRAFANA_DATABASE_PASS}';"
      ) | mysql ${mysql_opts}

      

    fi

  else


  fi

  touch ${initfile}
fi

echo -e "\n Starting Supervisor.\n  You can safely CTRL-C and the container will continue to run with or without the -d (daemon) option\n\n"

if [ -f /etc/supervisor.d/grafana.ini ]
then
  /usr/bin/supervisord >> /dev/null
else
  exec /bin/bash
fi

# EOF
