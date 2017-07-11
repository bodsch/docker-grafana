

startGrafana() {

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

  RETRY=35

  # wait for grafana
  #
  until [ ${RETRY} -le 0 ]
  do
    nc localhost 3000 < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] waiting for grafana to come up"

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [ $RETRY -le 0 ]
  then
    echo " [E] grafana is not successful started :("
    exit 1
  fi

  sleep 5s

  echo " [i] done"
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

  echo " [i] updating organistation to '${ORGANISATION}'"

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

  echo " [i] done"
}


handleDataSources() {

  curl_opts="--silent --user admin:admin"

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

      curl ${curl_opts} \
        --request PUT \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data-binary "{\"name\":\"${name}\",\"type\":\"${type}\",\"isDefault\":${default},\"access\":\"proxy\",\"url\":\"http://${GRAPHITE_HOST}:${GRAPHITE_HTTP_PORT}\"}" \
        http://localhost:3000/api/datasources/${id}

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

      curl ${curl_opts} \
        --request POST \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --data-binary @/init/config/template/datasource-${i}.json \
        http://localhost:3000/api/datasources/
    done
  fi

  sleep 2s

  echo " [i] done"
}


insertPlugins() {

  local plugins="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel"

  for p in ${plugins}
  do
    /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins"  plugins install ${p}
  done

}


updatePlugin() {

  echo " [i] update plugins"

  /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins upgrade-all

  echo " [i] done"
}


startGrafana

handleOrganisation
handleDataSources

# insertPlugins
updatePlugin

killGrafana
