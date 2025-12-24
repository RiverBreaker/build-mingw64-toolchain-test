#! /usr/bin/env sh
set -e

extract() {
    local file=$1
    local target_dir=$2
    local name=$(basename "$file")
}

download() {
    while [ $# -gt 0 ]; do
      case "$1" in
        --name=*)
          NAME="${1#*=}"
          shift
          ;;
        --url=*)
          URL="${1#*=}"
          shift
          ;;
        --download-to=*)
          DOWNLOAD_TO="${1#*=}"
          shift
          ;;
        *)
          echo "Unknown argument: $1"
          exit 1
          ;;
      esac
    done
    local file=$1
    local url=$2

    local download_dir=${DOWNLOAD_TO:-"./downloads"}
    local name=$(basename "$file")

    mkdir -p "$download_dir"
    curl -sSL "$url" -o "$download_dir/$name"
    echo "Downloaded $name"
}