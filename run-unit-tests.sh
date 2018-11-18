(set -e
  docker build -t nokia/kong-oidc-test .
  docker run -it --rm nokia/kong-oidc-test /bin/bash ./test/unit/run.sh
)
echo "Done"