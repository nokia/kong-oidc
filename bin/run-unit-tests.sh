#!/bin/bash
. .env

(set -ex
  docker build \
    -t ${BUILD_IMG_NAME} \
    -f ${UNIT_PATH}/Dockerfile .
  docker run -it --rm ${BUILD_IMG_NAME} /bin/bash test/unit/run.sh
)

echo "Done"