#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

GOOS=linux go build .
cp ./sample-apiserver ./artifacts/simple-image/kube-sample-apiserver
docker build -t tkxkd0159/kube-sample-apiserver:latest ./artifacts/simple-image

PUSH_IMAGE=false

if [[ "${1:-}" == "--push" ]]; then
    PUSH_IMAGE=true
fi

if [[ "$PUSH_IMAGE" == true ]]; then
    docker push tkxkd0159/kube-sample-apiserver
fi

rm ./sample-apiserver
