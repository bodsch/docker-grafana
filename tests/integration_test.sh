#!/bin/bash

GRAFANA_PORT="${GRAFANA_PORT:-3000}"

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

    sleep 10s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "could not connect to grafana"
    exit 1
  fi

#   sleep 2s
}


create_token() {

  curl_opts="--silent --user admin:admin"
  out_file="/tmp/grafana.test"

  code=$(curl \
    ${curl_opts} \
    --request POST \
    --header "Content-Type: application/json" \
    --write-out '%{http_code}\n' \
    --output ${out_file} \
    --data '{"name":"Spec Test", "role": "Admin"}' \
    http://localhost:${GRAFANA_PORT}/api/auth/keys)

  result=${?}

  echo "code: ${code}"

  if [[ ${result} -eq 0 ]] && [[ ${code} = 200 ]]
  then
    echo "token request are successfull"

    TOKEN=$(jq --raw-output .key ${out_file})

    export TOKEN
  else
    echo ${code}
    echo "api request failed"
  fi
}


api_request() {

  curl_opts="--silent "

  HEADERS=( "content-type: application/json;charset=UTF-8" )

  if [[ -z "${TOKEN}" ]]
  then
    curl_opts="${curl_opts} --user admin:admin"
  else
    HEADERS+=( "Authorization: Bearer ${TOKEN}" )
  fi


  for((i=0; i<${#HEADERS[@]}; i++)); do
    parameters+=("--header" "${HEADERS[$i]}");
  done


  data=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    http://localhost:${GRAFANA_PORT}/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  echo "current organisation: '${name}'"
  echo "update organistation to '${ORGANISATION}'"

  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
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

  echo "restore organistation to '${name}'"
  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request PUT \
    --data-binary "{\"name\":\"${name}\"}" \
    http://localhost:${GRAFANA_PORT}/api/org)


  echo "number of datasources"
  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request GET \
    http://localhost:${GRAFANA_PORT}/api/datasources)

  echo "  $(echo "${code}"  | jq --raw-output '.[].name' | wc -l)"

  echo "test render function"
  curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --output qa-test.png \
    "http://localhost:${GRAFANA_PORT}/render/d/qa-test/qa-test?orgId=1&theme=light&timeout=30"

  if [[ -f qa-test.png ]]
  then
    data=$(file \
      --mime \
      qa-test.png)
    # qa-test.png: image/png; charset=binary

    if [[ $? -eq 0 ]]
    then
      if [[ ${data} =~ image/png ]]
      then
        echo "  success"
      fi

    fi
  fi

}


inspect() {

  echo ""
  echo "inspect needed containers"
  for d in $(docker ps | tail -n +2 | awk  '{print($1)}')
  do
    c=$(docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d})
    s=$(docker inspect --format '{{json .State.Health }}' ${d} | jq --raw-output .Status)

    printf "%-40s - %s\n"  "${c}" "${s}"
  done
}


running_containers=$(docker ps | tail -n +2  | wc -l)

if [[ ${running_containers} -eq 4 ]] || [[ ${running_containers} -gt 4 ]]
then
  inspect

  #wait_for_grafana
  create_token
  api_request

  exit 0
else
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up -d"
  echo "before"

  exit 1
fi
