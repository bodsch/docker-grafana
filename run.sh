#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite)
DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --detach \
  --publish=3000:3000 \
  --link=${USER}-graphite:graphite \
  --link=${USER}-mysql:database \
  --env GRAPHITE_HOST=${GRAPHITE_IP} \
  --env GRAPHITE_PORT=8080 \
  --env DATABASE_GRAFANA_TYPE=mysql \
  --env DATABASE_GRAFANA_HOST=${DATABASE_IP} \
  --env DATABASE_GRAFANA_PORT=3306 \
  --env DATABASE_ROOT_USER=root \
  --env DATABASE_ROOT_PASS=${DOCKER_DBA_ROOT_PASS} \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
