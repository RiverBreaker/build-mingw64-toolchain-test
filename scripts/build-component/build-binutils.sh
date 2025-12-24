#! /usr/bin/env sh
set -e

while [ $# -gt 0 ];do
  case "$1" in
    --build-type=*)
      build_type="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

if [[ "${BUILD_TYPE}" == "cross" ]];then
  export BUILD="x86_64-pc-linux-gnu"
  export HOST="x86_64-pc-linux-gnu"
  export TARGET="x86_64-w64-mingw32"
elif [[ "${BUILD_TYPE}" == "native" ]];then
  export BUILD="x86_64-pc-linux-gnu"
  export HOST="x86_64-w64-mingw32"
  export TARGET="x86_64-w64-mingw32"
fi