#! /usr/bin/env sh
set -e

source ../function/functions.sh
source ../function/get_versions.sh
source ../../config/url.conf

echo "Downloading source files for GCC version: $GCC_VERSION"
# 构建下载目录

download \
  --name=gcc-"$GCC_VERSION".tar.xz \
  --url="$GCC_SOURCE_URL"/gcc-"$GCC_VERSION".tar.xz \
  --download-to="./sources"