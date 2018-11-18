. .env
. _network_functions

(set -e
  if [[ -z "$IP" ]]; then
    echo "Please set the IP var to your local IP address. Example: export IP=192.168.0.1"
    exit 1
  fi

  (set -x
    # Tear down environment if it is running
    docker-compose down
    docker build -t nokia/kong-oidc .
    docker-compose up -d kong-db
  )

  _wait_for_listener localhost:${KONG_DB_PORT}

  (set -x
    docker-compose run --rm kong kong migrations up
    docker-compose up -d
  )

  _wait_for_endpoint http://localhost:${KONG_HTTP_ADMIN_PORT}
  _wait_for_endpoint http://localhost:${KEYCLOAK_PORT}

  (set -x
    python3 setup.py
  )
)