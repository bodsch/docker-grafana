#!/usr/bin/env bash

test_import_dashboards() {

  echo " [i] start API tests"

  local curl_opts="--silent ${CURL_USER}"

  local slugs=()
  local fs_count=$(ls -1 /init/qa/*.json | wc -l)

  for f in $(ls -1 /init/qa/*.json)
  do
    echo -n "     import $(basename ${f})"

    data=$(curl \
      ${curl_opts} \
      --request POST \
      --header 'Content-Type: application/json;charset=UTF-8' \
      --data @${f} \
      http://localhost:3000/api/dashboards/db)

    slug=$(echo ${data} | jq  --raw-output '.slug' 2> /dev/null)
    status=$(echo ${data} | jq  --raw-output '.status' 2> /dev/null)

    if ( [ "${status}" = "success" ] && [ ! -z ${slug} ] )
    then
      echo "    ... successful"

      slugs+=(${slug})
    else
      echo "    ... error: ${data}"
    fi
  done

  data=$(curl \
    ${curl_opts} \
    --header 'Content-Type: application/json;charset=UTF-8' \
    "http://localhost:3000/api/search/?tag=QA")

  count=$(echo "${data}" | json_reformat | grep -c "id")

  echo -n "     found ${count} dashboards with QA tag"

  if [[ ${fs_count} -eq ${count} ]]
  then
    echo "    ... okay"
  else
    echo "    ... attention, I expect ${fs_count} but found ${count}"
  fi

  if [ ${count} -gt 0 ]
  then
    echo "     remove imported dashboards"

    for s in "${slugs[@]}"
    do
      echo -n "     - $(basename ${s})"

      data=$(curl \
        ${curl_opts} \
        --request DELETE \
        --header 'Content-Type: application/json;charset=UTF-8' \
        http://localhost:3000/api/dashboards/db/${s})

      title=$(echo ${data} | jq  --raw-output '.title' 2> /dev/null)

      if [[ ! -z ${title} ]]
      then
        echo "    ... successful"
      fi
    done
  fi
}
