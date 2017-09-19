

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
    kill -9 ${grafana_pid} > /dev/null 2> /dev/null

    sleep 2s
  fi
}



update_organisation() {

  echo " [i] updating organistation to '${ORGANISATION}'"

  curl_opts="--silent ${CURL_USER}"

  data=$(curl ${curl_opts} http://localhost:3000/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  if [ "${name}" != "${ORGANISATION}"  ]
  then
    data=$(curl \
      ${curl_opts} \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --request PUT \
      --data-binary "{\"name\":\"${ORGANISATION}\"}" \
      http://localhost:3000/api/org)
  fi
}


update_datasources() {

  echo " [i] updating datasources"

  curl_opts="--silent ${CURL_USER}"

  datasource_count=$(curl ${curl_opts} 'http://localhost:3000/api/datasources' | json_reformat | grep -c "id")

  if [ ${datasource_count} -gt 0 ]
  then

    echo " [i] update data sources"

    for c in $(seq 1 ${datasource_count})
    do
      # get type and id - we need it later!
      data=$(curl ${curl_opts} http://localhost:3000/api/datasources/${c})

      id=$(echo ${data} | jq  --raw-output '.id')
      name=$(echo ${data} | jq --raw-output '.name')
      type=$(echo ${data} | jq --raw-output '.type')
      default=$(echo ${data} | jq --raw-output '.isDefault')

      data=$(curl \
        ${curl_opts} \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --request PUT \
        --data-binary "{\"name\":\"${name}\",\"type\":\"${type}\",\"isDefault\":${default},\"access\":\"proxy\",\"url\":\"http://${GRAPHITE_HOST}:${GRAPHITE_HTTP_PORT}\"}" \
        http://localhost:3000/api/datasources/${id})

      message=

      if [ $(echo "${data}" | json_reformat | grep -c "message") -gt 0 ]
      then
        message=$(echo "${data}" | jq --raw-output '.message')
      fi

      if [ -z "${message}" ]
      then
        # possible okay
        :
      fi

    done
  else

    echo " [i] create data sources"

    for i in graphite events
    do
      cp /init/config/template/datasource.tpl /init/config/template/datasource-${i}.json

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
        /init/config/template/datasource-${i}.json

      data=$(curl \
        ${curl_opts} \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --request POST \
        --data-binary @/init/config/template/datasource-${i}.json \
        http://localhost:3000/api/datasources/)
    done
  fi

  sleep 2s
}


. /init/plugins.sh
. /init/authentications.sh
. /init/security.sh

start_grafana

validate_api_access
change_admin_password
# create_api_key

update_organisation
update_datasources

ldap_authentication

create_local_users

# insert_plugins
update_plugins

kill_grafana
