#!/bin/bash
. .env
. ${INTEGRATION_PATH}/_network_functions

(set -e
  if [[ -z "$IP" ]]; then
    echo "Please set the IP var to your local IP address. Example: export IP=192.168.0.1"
    exit 1
  fi

  (set -x
    # Tear down environment if it is running
    docker-compose -f ${INTEGRATION_PATH}/docker-compose.yml down 
    docker build --build-arg KONG_BASE_TAG=${KONG_BASE_TAG} -t nokia/kong-oidc -f ${INTEGRATION_PATH}/Dockerfile .
    docker-compose -f ${INTEGRATION_PATH}/docker-compose.yml up -d kong-db
  )

  _wait_for_listener localhost:${KONG_DB_PORT}

  (set -x
    docker-compose -f ${INTEGRATION_PATH}/docker-compose.yml run --rm kong kong migrations bootstrap
    docker-compose -f ${INTEGRATION_PATH}/docker-compose.yml up -d
  )

  _wait_for_endpoint http://localhost:${KONG_HTTP_ADMIN_PORT}
  _wait_for_endpoint http://localhost:${KEYCLOAK_PORT}

  (set -x
    python3 ${INTEGRATION_PATH}/setup.py
  )
)