#!/bin/bash
. .env

(set -ex
  docker build \
    --build-arg KONG_BASE_TAG=${KONG_BASE_TAG} \
    -t ${BUILD_IMG_NAME} \
    -f ${UNIT_PATH}/Dockerfile .
  docker run -it --rm ${BUILD_IMG_NAME} /bin/bash test/unit/run.sh
)

echo "Done"