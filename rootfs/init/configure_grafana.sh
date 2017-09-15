

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
    kill -9 ${grafana_pid}

    sleep 2s
  fi
}


create_api_key() {

  if [ -f ${WORK_DIR}/api_key ]
  then
    echo " [i] read API key"

    API_KEY=$(cat ${WORK_DIR}/api_key)

    export API_KEY
  else
    echo " [i] create API key"

    curl_opts="--silent --user admin:admin"

    data=$(curl ${curl_opts} \
      --silent \
      --request POST \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --data '{ "name": "admin", "role": "Admin" }' \
      http://localhost:3000/api/auth/keys)

    name=$(echo ${data} | jq  --raw-output '.name')
    key=$(echo ${data} | jq  --raw-output '.key')

    echo ${key} >> ${WORK_DIR}/api_key
  fi
}


update_organisation() {

  echo " [i] updating organistation to '${ORGANISATION}'"

  curl_opts="--silent"

  if [ -z ${API_KEY} ]
  then
    curl_opts="${curl_opts} --user admin:admin"
  else
    curl_opts="${curl_opts} --header 'Authorization: Bearer ${API_KEY}'"
  fi

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

  curl_opts="--silent"

  if [ -z ${API_KEY} ]
  then
    curl_opts="${curl_opts} --user admin:admin"
  else
    curl_opts="${curl_opts} --header 'Authorization: Bearer ${API_KEY}'"
  fi

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


ldap_authentication() {

  ldap=$(echo "${LDAP}"  | jq '.')

  if [ ! -z "${ldap}" ]
  then
    echo " [i] create LDAP configuration"
    . /init/auth_ldap.sh

    echo "${ldap}" | jq --compact-output --raw-output '.[]' | while IFS='' read u
    do
      server=$(echo "${u}" | jq .server)
      port=$(echo "${u}" | jq .port)
      bind_dn=$(echo "${u}" | jq .bind_dn)
      bind_password=$(echo "${u}" | jq .bind_password)
      base_dn=$(echo "${u}" | jq .base_dn)
      group_dn=$(echo "${u}" | jq .group_dn)

      ldap_configuation "${server}" "${port}" "${bind_dn}", "${bind_password}" "${base_dn}" "${group_dn}"
    done

  fi

#   if [ ! -z "${users}" ]
#   then
#
#     echo " [i] create users"
#
#     echo "${users}" | jq --compact-output --raw-output '.[]' | while IFS='' read u
#     do
#       username=$(echo "${u}" | jq .username)
#       password=$(echo "${u}" | jq .password)
#       email=$(echo "${u}" | jq .email)
#       role=$(echo "${u}" | jq .role)
#
#       insert_user "${username}" "${password}" "${email}", "${role}"
#     done
#   fi
}


insert_user() {

  local user="${1}"
  local password="${2}"
  local email="${3}"
  local role="${4}"

  local curl_opts="--silent --header 'Content-Type: application/json;charset=UTF-8'"

  [ -z ${password} ] && password=${user}
  [ -z ${email} ] && email="${user}@foo-bar.tld"
  [ -z ${role} ] && role="viewer"

  if [ ${#password} -lt 8 ]
  then
    echo " skip user '${user}'"
    echo " [E] Passwordlength is too short: password has ${#password} characters, please use min. 8 chars"

    continue
  fi

  echo "      - '${user}'"

  data=$(curl \
    ${curl_opts} \
    --request POST \
    --data "{ \"name\": \"${user}\", \"email\": \"${email}\", \"login\": \"${user}\", \"password\": \"${password}\" }" \
    http://localhost:3000/api/admin/users)

  id=$(echo ${data} | jq  --raw-output '.id')
  message=$(echo ${data} | jq  --raw-output '.message')

  if [ "${message}" = "User created" ]
  then
    # user successful created
    if [ $(echo "${role}" | tr '[:upper:]' '[:lower:]') == "admin" ]
    then

      data=$(curl \
        ${curl_opts} \
        --request PATCH \
        --data "{ \"role\": \"Admin\" }" \
        http://localhost:3000/api/org/users/${id})

      data=$(curl \
        ${curl_opts} \
        --request PUT \
        --data "{ \"isGrafanaAdmin\": true }" \
        http://localhost:3000/api/admin/users/${id}/permissions)

    fi
  fi

}


handle_users() {

  echo " [i] create users"

  users=$(echo "${USERS}"  | jq '.')

  if [ ! -z "${users}" ]
  then

    echo "${users}" | jq --compact-output --raw-output '.[]' | while IFS='' read u
    do
      username=$(echo "${u}" | jq .username)
      password=$(echo "${u}" | jq .password)
      email=$(echo "${u}" | jq .email)
      role=$(echo "${u}" | jq .role)

      insert_user "${username}" "${password}" "${email}", "${role}"
    done
  fi


  curl_opts="--silent --header 'Content-Type: application/json;charset=UTF-8'"

  if [ -z ${API_KEY} ]
  then
    curl_opts="${curl_opts} --user admin:admin"
  else
    curl_opts="${curl_opts} --header 'Authorization: Bearer ${API_KEY}'"
  fi

  users=

  if [ -n "${GRAFANA_USERS}" ]
  then
    users=$(echo ${GRAFANA_USERS} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)

    if [ -z "${users}" ]
    then
      echo " [i] no user found, skip .."

      return
    else
      for u in ${users}
      do

        user=$(echo "${u}" | cut -d: -f1)
        pass=$(echo "${u}" | cut -d: -f2)
        email=$(echo "${u}" | cut -d: -f3)
        role=$(echo "${u}" | cut -d: -f4)

        [ -z ${pass} ] && pass=${user}
        [ -z ${email} ] && email="${user}@foo-bar.tld"
        [ -z ${role} ] && role="viewer"

        if [ ${#pass} -lt 8 ]
        then
          echo " [E] Passwordlength for user '${user}' is too short: password has ${#pass} characters, please use min. 8 chars"
          continue
        fi

        echo "      - '${user}'"

        data=$(curl \
          ${curl_opts} \
          --request POST \
          --data "{ \"name\": \"${user}\", \"email\": \"${email}\", \"login\": \"${user}\", \"password\": \"${pass}\" }" \
          http://localhost:3000/api/admin/users)

        id=$(echo ${data} | jq  --raw-output '.id')
        message=$(echo ${data} | jq  --raw-output '.message')

        if [ "${message}" = "User created" ]
        then
          # user successful created
          if [ $(echo "${role}" | tr '[:upper:]' '[:lower:]') == "admin" ]
          then

            data=$(curl \
              ${curl_opts} \
              --request PATCH \
              --data "{ \"role\": \"Admin\" }" \
              http://localhost:3000/api/org/users/${id})

            data=$(curl \
              ${curl_opts} \
              --request PUT \
              --header 'Content-Type: application/json;charset=UTF-8' \
              --data "{ \"isGrafanaAdmin\": true }" \
              http://localhost:3000/api/admin/users/${id}/permissions)

          fi
        fi

      done

      # change admin password
      # PUT /api/admin/users/:id/password

      echo " [i] change default 'admin' password"
      data=$(curl \
        ${curl_opts} \
        --header 'Content-Type: application/json;charset=UTF-8' \
        --request PUT \
        --data '{"password":"grafana-admin"}' \
        http://localhost:3000/api/admin/users/1/password)

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
  fi
}


insert_plugins() {

  local plugins="grafana-clock-panel grafana-piechart-panel jdbranham-diagram-panel mtanda-histogram-panel"

  for p in ${plugins}
  do
    /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins"  plugins install ${p}
  done

}


update_plugins() {

  echo " [i] update plugins"

  /usr/share/grafana/bin/grafana-cli --pluginsDir "/usr/share/grafana/data/plugins" plugins upgrade-all

  echo " [i] done"
}


start_grafana

create_api_key

update_organisation
# update_datasources
update_authentication
handle_users

# insert_plugins
# update_plugins

kill_grafana
