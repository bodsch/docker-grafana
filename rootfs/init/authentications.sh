
ldap_configuation() {

  LDAP_SERVER=${LDAP_SERVER:-}
  LDAP_PORT=${LDAP_PORT:-389}
  LDAP_BIND_DN=${LDAP_BIND_DN:-''}
  LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-''}
  LDAP_BASE_DN=${LDAP_BASE_DN:-''}
  LDAP_GROUP_DN=${LDAP_GROUP_DN:-''}
  LDAP_SEARCH_FILTER=${LDAP_SEARCH_FILTER:-''}

  if ( [[ -z ${LDAP_SERVER} ]] || [[ ${LDAP_SERVER} == null ]] ); then
    return
  fi

  [[ ${#LDAP_SEARCH_FILTER} -eq 0 ]] && LDAP_SEARCH_FILTER="(cn=%s)"

  file="/etc/grafana/ldap.toml"

  log_info "create LDAP configuration"

  cat << EOF > ${file}

# take a look at http://docs.grafana.org/installation/ldap/
#

verbose_logging = false

[[servers]]
host = "${LDAP_SERVER}"
port = ${LDAP_PORT}
use_ssl = false
start_tls = false
ssl_skip_verify = false

bind_dn = "${LDAP_BIND_DN}"
bind_password = '${LDAP_BIND_PASSWORD}'

search_filter = "${LDAP_SEARCH_FILTER}"

search_base_dns = ["${LDAP_BASE_DN}"]

[servers.attributes]
name = "givenName"
surname = "sn"
username = "cn"
member_of = "memberOf"
email =  "email"

[[servers.group_mappings]]
group_dn = "${LDAP_GROUP_DN}"
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

  # default values for our Environment
  #
  LDAP_SERVER=${LDAP_SERVER:-}
  LDAP_PORT=${LDAP_PORT:-389}
  LDAP_BIND_DN=${LDAP_BIND_DN:-''}
  LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-''}
  LDAP_BASE_DN=${LDAP_BASE_DN:-''}
  LDAP_GROUP_DN=${LDAP_GROUP_DN:-''}
  LDAP_SEARCH_FILTER=${LDAP_SEARCH_FILTER:-''}

  USE_JSON="true"

  # detect if 'ICINGA_CERT_SERVICE' an json
  #
  if ( [[ ! -z "${LDAP}" ]] && [[ "${LDAP}" != "true" ]] && [[ "${LDAP}" != "false" ]] )
  then
    echo "${LDAP}" | json_verify -q 2> /dev/null

    if [[ $? -gt 0 ]]
    then
      #log_info "the LDAP Environment is not an json"
      USE_JSON="false"
    fi
  else
    #log_info "the LDAP Environment is not an json"
    USE_JSON="false"
  fi

  # we can use json as configure
  #
  if [[ "${USE_JSON}" == "true" ]]
  then
    if ( [[ "${LDAP}" == "true" ]] || [[ "${LDAP}" == "false" ]] )
    then
      log_warn "the LDAP Environment must be an json, not true or false!"
    else
      server=$(echo "${u}" | jq --raw-output .server)
      port=$(echo "${u}" | jq --raw-output .port)
      bind_dn=$(echo "${u}" | jq --raw-output .bind_dn)
      bind_password=$(echo "${u}" | jq --raw-output .bind_password)
      base_dn=$(echo "${u}" | jq --raw-output .base_dn)
      group_dn=$(echo "${u}" | jq --raw-output .group_dn)
      search_filter=$(echo "${u}" | jq --raw-output .search_filter)

      [[ "${server}" == null ]] && LDAP_SERVER=
      [[ "${port}" == null ]] && LDAP_PORT=389
      [[ "${bind_dn}" == null ]] && LDAP_BIND_DN=
      [[ "${bind_password}" == null ]] && LDAP_BIND_PASSWORD=
      [[ "${base_dn}" == null ]] && LDAP_BASE_DN=
      [[ "${group_dn}" == null ]] && LDAP_GROUP_DN=
      [[ "${search_filter}" == null ]] && LDAP_SEARCH_FILTER=
    fi
  else
    LDAP_SERVER=${LDAP_SERVER:-}
    LDAP_PORT=${LDAP_PORT:-389}
    LDAP_BIND_DN=${LDAP_BIND_DN:-''}
    LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-''}
    LDAP_BASE_DN=${LDAP_BASE_DN:-''}
    LDAP_GROUP_DN=${LDAP_GROUP_DN:-''}
    LDAP_SEARCH_FILTER=${LDAP_SEARCH_FILTER:-''}
  fi

  validate_ldap_environment

  ldap_configuation
}


validate_ldap_environment() {

    LDAP_SERVER=${LDAP_SERVER:-}
    LDAP_PORT=${LDAP_PORT:-389}
    LDAP_BIND_DN=${LDAP_BIND_DN:-''}
    LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-''}
    LDAP_BASE_DN=${LDAP_BASE_DN:-''}
    LDAP_GROUP_DN=${LDAP_GROUP_DN:-''}
    LDAP_SEARCH_FILTER=${LDAP_SEARCH_FILTER:-''}

  # use the new Cert Service to create and get a valide certificat for distributed icinga services
  #
  if (
    [[ ! -z ${LDAP_SERVER} ]] &&
    [[ ! -z ${LDAP_PORT} ]] &&
    [[ ! -z ${LDAP_BIND_DN} ]] &&
    [[ ! -z ${LDAP_BIND_PASSWORD} ]] &&
    [[ ! -z ${LDAP_BASE_DN} ]] &&
    [[ ! -z ${LDAP_GROUP_DN} ]] &&
    [[ ! -z ${LDAP_SEARCH_FILTER} ]]
  )
  then
    USE_LDAP=true

    export LDAP_SERVER
    export LDAP_PORT
    export LDAP_BIND_DN
    export LDAP_BIND_PASSWORD
    export LDAP_BASE_DN
    export LDAP_GROUP_DN
    export LDAP_SEARCH_FILTER
    export USE_LDAP
  fi
}

