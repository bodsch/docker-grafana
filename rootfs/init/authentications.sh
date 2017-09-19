
ldap_configuation() {

  local server=${1}
  local port=${2}
  local bind_dn=${3}
  local bind_password=${4}
  local base_dn=${5}
  local group_dn=${6}
  local search_filter=${7}

  [ ${#port} -eq 0 ] && port=389
  [ ${#search_filter} -eq 0 ] && search_filter="(cn=%s)"

  file="/etc/grafana/ldap.toml"

  cat << EOF > ${file}

# take a look at http://docs.grafana.org/installation/ldap/
#

verbose_logging = false

[[servers]]
host = "${server}"
port = ${port}
use_ssl = false
start_tls = false
ssl_skip_verify = false

bind_dn = "${bind_dn}"
bind_password = "${bind_password}"

search_filter = "${search_filter}"

search_base_dns = ["${base_dn}"]

[servers.attributes]
name = "givenName"
surname = "sn"
username = "cn"
member_of = "memberOf"
email =  "email"

[[servers.group_mappings]]
group_dn = "${group_dn}"
org_role = "Admin"

EOF

  file="/etc/grafana/grafana.ini"

  cat << EOF >> ${file}

[auth.ldap]
enabled           = true
config_file       = /etc/grafana/ldap.toml

EOF

}


ldap_authentication() {

  ldap=$(echo "${LDAP}"  | jq '.')

  if [ ! -z "${ldap}" ]
  then
    echo " [i] create LDAP configuration"

    echo "${ldap}" | jq --compact-output --raw-output '.' | while IFS='' read u
    do
      server=$(echo "${u}" | jq --raw-output .server)
      port=$(echo "${u}" | jq --raw-output .port)
      bind_dn=$(echo "${u}" | jq --raw-output .bind_dn)
      bind_password=$(echo "${u}" | jq --raw-output .bind_password)
      base_dn=$(echo "${u}" | jq --raw-output .base_dn)
      group_dn=$(echo "${u}" | jq --raw-output .group_dn)
      search_filter=$(echo "${u}" | jq --raw-output .search_filter)

      ldap_configuation "${server}" "${port}" "${bind_dn}" "${bind_password}" "${base_dn}" "${group_dn}" "${search_filter}"
    done

  fi

#   if [ ! -z "${users}" ]
#   then
#
#     echo " [i] create users"
#
#     echo "${users}" | jq --compact-output --raw-output '.' | while IFS='' read u
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

  local user=${1}
  local password=${2}
  local email=${3}
  local role=${4}

  [ -z ${user} ] && return

  local curl_opts="--silent ${CURL_USER}"

  [ ${#password} -eq 0 ] && password=${user}
  [ ${#email} -eq 0 ] && email="${user}@foo-bar.tld"
  [ ${#role} -eq 0 ] && role="viewer"

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
    --header 'Content-Type: application/json;charset=UTF-8' \
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
        --header 'Content-Type: application/json;charset=UTF-8' \
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

}


create_local_users() {

  if [ ! -z "${USERS}" ]
  then

    echo " [i] create local users"

    echo "${USERS}" | jq --compact-output --raw-output '.[]' | while IFS='' read u
    do
      username=$(echo "${u}" | jq --raw-output .username)
      password=$(echo "${u}" | jq --raw-output .password)
      email=$(echo "${u}" | jq --raw-output .email)
      role=$(echo "${u}" | jq --raw-output .role)

      insert_user "${username}" "${password}" "${email}" "${role}"
    done
  fi
}


