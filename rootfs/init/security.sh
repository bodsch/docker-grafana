

validate_api_access() {

  success=false
  curl_opts=

  basic_credentials=()

  if [ -f ${WORK_DIR}/api_key ]
  then
    API_KEY=$(cat ${WORK_DIR}/api_key)
    basic_credentials+=("--header \"Authorization: Bearer ${API_KEY}\"")
  fi

  if ( [[ ! -z ${ADMIN_PASSWORD} ]] || [[ ${ADMIN_PASSWORD} != "" ]] )
  then
    basic_credentials+=("--user admin:${ADMIN_PASSWORD}")
  fi

  basic_credentials+=('--user admin:admin' '--user admin:grafana-admin')

  for i in "${basic_credentials[@]}"
  do
    data=$(curl \
      ${i} \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --silent \
      http://localhost:3000/api/users)

    message=

    if [ $(echo "${data}" | json_reformat | grep -c "message") -gt 0 ]
    then
      message=$(echo "${data}" | jq --raw-output '.message')
    fi

    if [ -z "${message}" ]
    then
      # possible okay
      users_count=$(echo "${data}" | json_reformat | grep -c "id")

      if [ ${users_count} -gt 0 ]
      then
        success=true
        curl_opts=${i}

        break
      fi

    elif ( [ "${message}" == "Unauthorized" ] || [ "${message}" == "Permission denied" ] || [ "${message}" == "Invalid username or password" ] )
    then

      if [[ ${i} =~ .*Authorization:\ Bearer.* ]]
      then
        rm -f ${WORK_DIR}/api_key 2> /dev/null
        unset API_KEY
      fi
    fi
  done

  if [ ${success} == true ]
  then
    export CURL_USER="${curl_opts}"
  fi
}


change_admin_password() {

  if ( [[ ! -z ${ADMIN_PASSWORD} ]] || [[ ${ADMIN_PASSWORD} != "" ]] || [[ ! -f ${WORK_DIR}/admin ]] )
  then

    curl_opts="--silent ${CURL_USER}"

    # change admin password
    # PUT /api/admin/users/:id/password

    echo -n " [i] change default 'admin' password  "
    data=$(curl \
      ${curl_opts} \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --request PUT \
      --data $(printf {\"password\":\"%s\"} ${ADMIN_PASSWORD}) \
      http://localhost:3000/api/admin/users/1/password)

    id=$(echo ${data} | jq  --raw-output '.id')
    message=$(echo ${data} | jq  --raw-output '.message')

    if [ "${message}" = "User password updated" ]
    then
      echo " ... successful"

      echo ${ADMIN_PASSWORD} > ${WORK_DIR}/admin

      CURL_USER=$(echo ${CURL_USER} | sed "s|:.*|:${ADMIN_PASSWORD}|g")
      export CURL_USER
    fi

#       # change permissions from 'Admin' to 'Viewer'
#       # PUT /api/admin/users/:id/permissions
#       curl \
#         ${curl_opts} \
#         --request PUT \
#         --header 'Content-Type: application/json;charset=UTF-8' \
#         --data '{"isGrafanaAdmin": false}' \
#         http://localhost:3000/api/admin/users/1/permissions
#
#       # alternative:
#       # DELETE admin user
#       # DELETE /api/admin/users/:id
#       curl \
#         ${curl_opts} \
#         --request DELETE \
#         --header 'Content-Type: application/json;charset=UTF-8' \
#         http://localhost:3000/api/admin/users/1

  fi
}


create_api_key() {

  if [ -f ${WORK_DIR}/api_key ]
  then
    echo " [i] read API key"

    API_KEY=$(cat ${WORK_DIR}/api_key)

    export API_KEY
  else

    curl_opts="${CURL_USER}"    #--user admin:admin"

    # first: check if key exists and delete them!
    data=$(curl \
      ${curl_opts} \
      --silent \
      http://localhost:3000/api/auth/keys)

    message=
    if [ $(echo "${data}" | json_reformat | grep -c "message") -gt 0 ]
    then
      message=$(echo "${data}" | jq --raw-output '.message')
    fi

    if [ -z "${message}" ]
    then
      id=$(echo "${data}" | jq  --raw-output '.[].id')
      name=$(echo "${data}" | jq  --raw-output '.[].name')

      if [ "${name}" == "admin" ]
      then

        echo " [i] delete old API key"
        data=$(curl \
          ${curl_opts} \
          --silent \
          --request DELETE \
          http://localhost:3000/api/auth/keys/${id})

      fi
      # curl --user admin:grafana-admin -X DELETE http://localhost:3000/api/auth/keys/1
    fi

    echo " [i] create API key"

    # SECOND: create the API Key (again)
    data=$(curl \
      ${curl_opts} \
      --silent \
      --request POST \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --data '{ "name": "admin", "role": "Admin" }' \
      http://localhost:3000/api/auth/keys)

    message=

    if [ $(echo "${data}" | json_reformat | grep -c "message") -gt 0 ]
    then
      message=$(echo "${data}" | jq --raw-output '.message')
    fi

    if [ -z "${message}" ]
    then
      # possible okay
      name=$(echo ${data} | jq  --raw-output '.name')
      key=$(echo ${data} | jq  --raw-output '.key')

      echo " [i]   API Key: ${key}"

      echo ${key} > ${WORK_DIR}/api_key
    else
      echo " [E] : ${message}"

      rm -f ${WORK_DIR}/api_key
      unset API_KEY
    fi
  fi
}
