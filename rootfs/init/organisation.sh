
update_organisation() {

  log_info "updating organistation to '${ORGANISATION}'"

  curl_opts="--silent --user admin:admin"

  data=$(curl ${curl_opts} http://localhost:3000/api/org)

  name=$(echo ${data} | jq --raw-output '.name')

  if [[ "${name}" != "${ORGANISATION}" ]]
  then
    data=$(curl \
      ${curl_opts} \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --request PUT \
      --data-binary "{\"name\":\"${ORGANISATION}\"}" \
      http://localhost:3000/api/org)
  fi
}
