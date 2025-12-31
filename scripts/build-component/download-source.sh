set -euo pipefail
export GITHUB_WORKSPACE="/home/build/build-mingw"
export GCC_VERSION="13.2.0"
source "${GITHUB_WORKSPACE}/scripts/functions.sh"

info "GCC 版本: ${GCC_VERSION}"
DEP_JSON_FILE="${GITHUB_WORKSPACE}/dependencies.json"
run "获取组件版本信息" export_versions_from_json "${DEP_JSON_FILE}" "${GCC_VERSION}" local

export GITHUB_BASE_URL="https://github.com"
export GNU_BASE_URL="https://ftp.gnu.org/gnu"

# optional tuning
export FORCE_COLOR=1
mkdir -p "${LOG_DIR}"
IGNORE_REGEX='array subscript 0 is outside array bounds'
LOG_TAIL_LINES=80
FAIL_ON_FATAL_IN_SUCCESS=1

export SOURCE_CODE_DIR="${GITHUB_WORKSPACE}/source-code" && mkdir -p "${SOURCE_CODE_DIR}"

gnu_pkgs=( gcc binutils libiconv make readline gdb )
github_pkgs=( mingw-w64 ninja cmake pkgconf expat zlib )

for p in "${gnu_pkgs[@]}";do
  if [[ "${p}" == "gcc" ]]; then
    ver="${GCC_VERSION}"
    echo "下载${p} 源码版本: ${ver}"
    run "下载${p}-${ver} 源码" curl_download "${GNU_BASE_URL}/${p}/${p}-${ver}/${p}-${ver}.tar.gz" "${SOURCE_CODE_DIR}"
    run "解压${p}-${ver} 源码" archive_extract "${p}" "${SOURCE_CODE_DIR}/${p}-${ver}.tar.gz" "${SOURCE_CODE_DIR}"
  else
    val="$(echo "$p" | tr '[:lower:]' '[:upper:]')"
    ver=${!val}
    run "下载${p}-${ver} 源码" curl_download "${GNU_BASE_URL}/${p}/${p}-${ver}.tar.gz" "${SOURCE_CODE_DIR}"
    run "解压${p}-${ver} 源码" archive_extract "${p}" "${SOURCE_CODE_DIR}/${p}-${ver}.tar.gz" "${SOURCE_CODE_DIR}"
  fi
done
for p in "${github_pkgs[@]}";do
  case "${p}" in
    mingw-w64)
    ver="${MINGW_W64}"
    github_author="mingw-w64"
    project_name="mingw-w64"
    ;;
    pkgconf)
    pkg_name=${p^^}
    ver="${!pkg_name}"
    github_author="${p}"
    project_name="${p}"
    ;;
    ninja)
    ver="${NINJA}"
    github_author="ninja-build"
    project_name="ninja"
    ;;
    cmake)
    ver="${CMAKE}"
    github_author="Kitware"
    project_name="CMake"
    ;;
    expat)
    ver="${EXPAT}"
    github_author="libexpat"
    project_name="libexpat"
    ;;
    zlib)
    ver="${ZLIB}"
    github_author="madler"
    project_name="zlib"
    ;;
    pdcurses)
    ver="${PDCURSES}"
    github_author="wmcbrine"
    project_name="PDCurses"
    ;;
    *)
    error "未知的 GitHub 包: ${p}"
    exit 1
    ;;
  esac
  if [[ "${p}" == "pkgconf" ]] || [[ "${p}" == "expat" ]]; then
    tail="${p}-${ver}.tar.gz"
  elif [[ "${p}" == "pdcurses" ]]; then
    tail="${ver}.tar.gz"
  else
    tail="v${ver}.tar.gz"
  fi
  EXPAT_TAG="R_${ver//./_}"
  if [[ "${p}" == "expat" ]]; then
    URL="${GITHUB_BASE_URL}/${github_author}/${project_name}/releases/download/${EXPAT_TAG}/${tail}"
  else
    URL="${GITHUB_BASE_URL}/${github_author}/${project_name}/archive/refs/tags/${tail}"
  fi
  run "下载${p}-${ver} 源码" curl_download "${URL}" "${SOURCE_CODE_DIR}"
  run "解压${p}-${ver} 源码" archive_extract "${p}" "${SOURCE_CODE_DIR}/${tail}" "${SOURCE_CODE_DIR}"
done

info "下载与解压步骤完成"