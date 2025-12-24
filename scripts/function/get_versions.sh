#! /usr/bin/env sh
set -e

while [ $# -gt 0 ]; do
    case "$1" in
        --gcc-version)
            GCC_VERSION="$1"
            shift 2
            ;;
        -f|--file)
            FILE="$1"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# 检查是否安装了jq
if ! command -v jq &> /dev/null; then
    sudo apt-get install -y jq 2> /dev/null || sudo yum install -y jq 2> /dev/null || brew install jq 2> /dev/null
fi



