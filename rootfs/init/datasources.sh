#!/usr/bin/env bash

# set -x
# set -e

insert_datasource () {

  local type=${1}
  local name=${2}
  local host=${3}
  local port=${4}
  local database=${5}
  local default=${6}
  local ba="false"
  local ba_user=${7}
  local ba_password=${7}
  local json_data=null

  if ( [ -z ${type} ] || [ -z ${name} ] || [ -z ${host} ] )
  then
    echo " [E] wrong arguments"
    return
  fi

  local curl_opts="--silent ${CURL_USER}"

  if ( [ ! -z ${ba_user} ] && [ ! -z ${ba_password} ] )
  then
    ba="true"
  fi

  if [ "${type}" == "graphite" ]
  then
    json_data='{"graphiteVersion":"1.0"}'
  fi



  template_file="/init/config/template/datasource-${type}-${name}.json"

    cat << EOF > ${template_file}
{
   "user" : "",
   "password" : "",
   "basicAuth" : ${ba},
   "basicAuthUser" : "${ba_user}",
   "basicAuthPassword" : "${ba_password}",
   "withCredentials" : false,
   "access" : "proxy",
   "type" : "${type}",
   "url" : "http://${host}:${port}",
   "name" : "${name}",
   "database" : "${database}",
   "isDefault" : ${default},
   "jsonData" : ${json_data},
   "orgId" : 1
}

EOF

  echo -n "     - ${type}: ${name}"

  data=$(curl \
    ${curl_opts} \
    --header 'Content-Type: application/json;charset=UTF-8' \
    --request POST \
    --data-binary @${template_file} \
    http://localhost:3000/api/datasources/)


  id=$(echo ${data} | jq  --raw-output '.id')
  message=$(echo ${data} | jq  --raw-output '.message')

  if [ "${message}" = "Datasource added" ]
  then
    echo "    ... successful"
  fi
}



read_datasources() {

  if [ ! -z "${DATASOURCES}" ]
  then

    count_defaults=$(echo "${DATASOURCES}" | \
      jq --raw-output  '.[] |
      map({default: .default}) |
      group_by(.default) |
      .[] | .[] |
      select( .default == true) |
      .default' | \
      wc -l)

    if [ ${count_defaults} -eq 0 ]
    then
      echo " [E] no default datasource is defined"
      exit 1

    elif [ ${count_defaults} -gt 1 ]
    then
      echo " [E] only one default datasource can be defined"
      exit 1
    fi

    echo " [i] create datasources"

    types+=('influxdb' 'graphite')

    for t in "${types[@]}"
    do
      echo "${DATASOURCES}" | jq --compact-output --raw-output ".${t}" | while IFS='' read d
      do

        if [[ ${d} == null ]]
        then
          continue
        fi

        echo "${d}" | jq --compact-output --raw-output ".[]" | while IFS='' read x
        do

          if [[ ${x} == null ]]
          then
            continue
          fi

          name=$(echo "${x}" | jq --raw-output .name)
          host=$(echo "${x}" | jq --raw-output .host)
          port=$(echo "${x}" | jq --raw-output .port)
          database=$(echo "${x}" | jq --raw-output .database)
          basic_auth_user=$(echo "${x}" | jq --raw-output .basic_auth.user)
          basic_auth_password=$(echo "${x}" | jq --raw-output .basic_auth.password)
          default=$(echo "${x}" | jq --raw-output .default)

          if [ "${t}" == "influxdb" ]
          then
            ( [ "${port}" == "" ] || [ ${port} == null ] ) && port=8086
          elif [ "${t}" == "graphite" ]
          then
            ( [ "${port}" == "" ] || [ ${port} == null ] ) && port=2003
          else
            continue
          fi

          ( [ ${default} == "" ] || [ ${default} == null ] )  && default="false"
          [ ${basic_auth_user} == null ] && basic_auth_user=
          [ ${basic_auth_password} == null ] && basic_auth_password=


          insert_datasource "${t}" "${name}" "${host}" "${port}" "${database}" "${default}" "${basic_auth_user}" "${basic_auth_password}"
        done
      done
    done
  fi
}


update_datasources() {

  curl_opts="--silent ${CURL_USER}"

  datasource_count=$(curl ${curl_opts} 'http://localhost:3000/api/datasources' | json_reformat | grep -c "id")

  if [ ${datasource_count} -gt 0 ]
  then

    echo " [i] update datasources"

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

    read_datasources
  fi

  sleep 2s
}
