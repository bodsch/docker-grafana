#!/bin/bash

GRAFANA_PORT="${GRAFANA_PORT:-3030}"
ORGANISATION="Spec Test"

CURL=$(which curl 2> /dev/null)
NC=$(which nc 2> /dev/null)
NC_OPTS="-z"

wait_for_grafana() {

  echo "wait for grafana"
  RETRY=35
  until [[ ${RETRY} -le 0 ]]
  do
    ${NC} ${NC_OPTS} localhost ${GRAFANA_PORT} < /dev/null > /dev/null

    [[ $? -eq 0 ]] && break

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "could not connect to grafana"
    exit 1
  fi

  sleep 2s
}

api_request() {

  curl_opts="--silent --user admin:admin"

  data=$(curl ${curl_opts} http://localhost:${GRAFANA_PORT}/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  echo "current organisation: '${name}'"
  echo "update organistation to '${ORGANISATION}'"

  code=$(curl \
    ${curl_opts} \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request PUT \
    --data-binary "{\"name\":\"${ORGANISATION}\"}" \
    http://localhost:${GRAFANA_PORT}/api/org)

  if [[ $? -eq 0 ]]
  then
    echo "api request are successfull"
    echo "${code}" | jq --raw-output ".message"
  else
    echo ${code}
    echo "api request failed"
  fi
}

inspect() {

  echo "inspect needed containers"
  for d in $(docker-compose ps | tail +3 | awk  '{print($1)}')
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d}
  done
}

echo "wait 1 minute1 for start"
sleep 1m

if [[ $(docker-compose ps | grep -c grafana-test) -eq 1 ]]
then
  inspect

  wait_for_grafana
  api_request

  exit 0
else
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up -d"
  echo "before"

  exit 1
fi
