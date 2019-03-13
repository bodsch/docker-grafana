#!/bin/bash

set -x
set -e

GRAFANA_PORT="${GRAFANA_PORT:-3000}"

ORGANISATION="Spec Test"

CURL=$(which curl 2> /dev/null)
NC=$(which nc 2> /dev/null)
NC_OPTS="-z"

API_TOKEN_FILE="/tmp/grafana.test"
RENDER_PNG="/tmp/qa-test.png"

wait_for_grafana() {

  echo -e "\nwait for grafana"
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

  echo -e "\ncreate API token"

  api_key="Spec Test"

  curl_opts="--silent --insecure --user admin:admin"

  data=$(curl \
    ${curl_opts} \
    --header "Content-Type: application/json" \
    https://localhost/grafana/api/auth/keys)

  result=${?}

  existing_api_key=$(echo "${data}" | jq --raw-output .[].name)

  if [[ -n ${existing_api_key} ]] && [[ -f ${API_TOKEN_FILE} ]]
  then
    echo "  reuse token"

    TOKEN=$(jq --raw-output .key ${API_TOKEN_FILE})
    API_NAME=$(jq --raw-output .name ${API_TOKEN_FILE})
  else

    code=$(curl \
      ${curl_opts} \
      --request POST \
      --header "Content-Type: application/json" \
      --write-out '%{http_code}\n' \
      --output ${API_TOKEN_FILE} \
      --data "{\"name\":\"${api_key}\", \"role\": \"Admin\"}" \
      https://localhost/grafana/api/auth/keys)

    result=${?}

    if [[ ${result} -eq 0 ]] && [[ ${code} = 200 ]]
    then
      echo "  token request are successfull"

      TOKEN=$(jq --raw-output .key ${API_TOKEN_FILE})

      export TOKEN
    else
      echo ${code}
      echo "  token request failed"

      exit 1
    fi

  fi
}


remove_token() {

  curl_opts="--silent --insecure "

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

  curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --request DELETE \
    --header "Content-Type: application/json" \
    https://localhost/grafana/api/auth/keys/1

  rm -f ${API_TOKEN_FILE}

}


api_request() {

  echo ""

  curl_opts="--silent --insecure "

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
    https://localhost/grafana/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  echo "current organisation: '${name}'"
  echo "update organistation to '${ORGANISATION}'"

  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request PUT \
    --data-binary "{\"name\":\"${ORGANISATION}\"}" \
    https://localhost/grafana/api/org)

  if [[ $? -eq 0 ]]
  then
    echo "  api request are successfull"
    echo "${code}" | jq --raw-output ".message"
  else
    echo ${code}
    echo "  api request failed"
  fi

  echo -e "\nrestore organistation to '${name}'"
  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request PUT \
    --data-binary "{\"name\":\"${name}\"}" \
    https://localhost/grafana/api/org)

  echo -e "\nnumber of datasources"
  code=$(curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --request GET \
    --header 'Content-Type: application/json;charset=UTF-8' \
    https://localhost/grafana/api/datasources)

  echo "  $(echo "${code}"  | jq --raw-output '.[].name' | wc -l)"

  echo "test render function"
  curl \
    ${curl_opts} \
    "${parameters[@]}" \
    --output "${RENDER_PNG}" \
    "https://localhost/grafana/render/d/qa-test/qa-test?orgId=1&theme=light&timeout=30"

  if [[ -f "${RENDER_PNG}" ]]
  then
    data=$(file \
      --mime \
      "${RENDER_PNG}")

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

  echo -e "\ninspect needed containers"
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

  [[ -f "${API_TOKEN_FILE}" ]] && rm -f "${API_TOKEN_FILE}"
  [[ -f "${RENDER_PNG}" ]] && rm -f "${RENDER_PNG}"

  inspect

  wait_for_grafana
  create_token
  api_request

  remove_token

  exit 0
else
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up -d"
  echo "before"

  exit 1
fi
