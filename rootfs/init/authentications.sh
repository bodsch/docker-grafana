
ldap_configuation() {

  local server=${1}
  local port=${2}
  local bind_dn=${3}
  local bind_password=${4}
  local base_dn=${5}
  local group_dn=${6}
  local search_filter=${7}

  if ( [ -z ${server} ] || [ ${server} == null ] ); then
    return
  fi

  [ ${#port} -eq 0 ] && port=389
  [ ${#search_filter} -eq 0 ] && search_filter="(cn=%s)"

  file="/etc/grafana/ldap.toml"

  echo " [i] create LDAP configuration"

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

  if [ ! -z "${LDAP}" ]
  then

    echo "${LDAP}" | json_verify -q 2> /dev/null

    if [ $? -gt 0 ]
    then
      echo " [W] the LDAP Environment is not an json."
      echo " [W] use skip this configuration part."
      return
    fi


    ldap=$(echo "${LDAP}"  | jq '.')

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
}
