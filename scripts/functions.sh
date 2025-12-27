#!/usr/bin/env bash
# functions.sh - CI-friendly logging & multi-error-aware helpers
# Usage: source functions.sh
# --------------------------------------------------------------

set -u
set -o pipefail

# -------------------- Configurable variables --------------------
: "${LOG_DIR:=logs}"
: "${LOG_TAIL_LINES:=50}"
: "${ERROR_REGEX:=error:|fatal error|undefined reference|collect2:|internal compiler error|segmentation fault|make: \\*\\*\\*|configure: error}"
: "${FATAL_REGEX:=internal compiler error|segmentation fault|undefined reference|internal compiler error:}"
: "${IGNORE_REGEX:=array subscript 0 is outside array bounds}"
: "${FAIL_ON_FATAL_IN_SUCCESS:=1}"

mkdir -p "$LOG_DIR"

# -------------------- Color / timestamp --------------------
_use_color=0
if [[ -n "${FORCE_COLOR:-}" ]]; then
  _use_color=1
elif [[ -t 1 ]]; then
  _use_color=1
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  _use_color=1
fi

if [[ $_use_color -eq 1 ]]; then
  RED=$'\033[31m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
  TS=$'\033[36m'
else
  RED=''
  YELLOW=''
  BLUE=''
  BOLD=''
  RESET=''
  TS=''
fi


timestamp() { date +"%H:%M:%S"; }

info()  { echo -e "${TS}[$(timestamp)] ${BLUE} INFO:${RESET} $*"; }
warn()  { echo -e "${TS}[$(timestamp)] ${YELLOW} WARN:${RESET} $*" >&2; }
die()   { local msg="$1"; local code="${2:-1}"; echo -e "${TS}[$(timestamp)] ${RED}${BOLD} ERROR:${RESET} $msg" >&2; exit "$code"; }

# -------------------- Internal helpers --------------------
_sanitize() { echo "$*" | tr ' /:|()' '___' | tr -s '_' ; }

_extract_errors() {
  local logfile="$1"
  if [[ -z "$IGNORE_REGEX" ]]; then
    grep -nEi -- "$ERROR_REGEX" "$logfile" || true
  else
    grep -nEi -- "$ERROR_REGEX" "$logfile" | grep -vEi -- "$IGNORE_REGEX" || true
  fi
}

_extract_fatals() {
  local logfile="$1"
  if [[ -z "$IGNORE_REGEX" ]]; then
    grep -nEi -- "$FATAL_REGEX" "$logfile" || true
  else
    grep -nEi -- "$FATAL_REGEX" "$logfile" | grep -vEi -- "$IGNORE_REGEX" || true
  fi
}

_print_context() {
  local logfile="$1"; local lineno="$2"; local before="${3:-10}"; local after="${4:-20}"
  if [[ -z "$lineno" || ! "$lineno" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  local start=$(( lineno - before ))
  if (( start < 1 )); then start=1; fi
  local end=$(( lineno + after ))
  sed -n "${start},${end}p" "$logfile"
}

error_summary() {
  local logfile="$1"
  local summary="${logfile}.summary"
  {
    echo "==== ERROR SUMMARY ($(basename "$logfile")) ===="
    echo
    echo "=> Found error/fatal matches (first 50):"
    _extract_errors "$logfile" | head -n 50 || true
    echo
    echo "=> Found fatal matches (if any):"
    _extract_fatals "$logfile" | head -n 50 || true
    echo
    echo "=> First error context (if any):"
    local first_line
    first_line="$(_extract_errors "$logfile" | head -n1 | cut -d: -f1 || true)"
    if [[ -n "$first_line" ]]; then
      _print_context "$logfile" "$first_line" 10 20
    else
      echo "(no error line found)"
    fi
    echo
    echo "==== LAST ${LOG_TAIL_LINES} LINES ===="
    tail -n "$LOG_TAIL_LINES" "$logfile" || true
  } >"$summary"
  echo "$summary"
}

_scan_log_for_fatal_and_maybe_fail() {
  local logfile="$1"
  local fatals
  fatals="$(_extract_fatals "$logfile" | head -n 100)" || true
  if [[ -n "$fatals" ]]; then
    warn "检测到致命错误（即使命令返回 0）："
    echo "----------------------------------------" >&2
    echo "$fatals" >&2
    echo "----------------------------------------" >&2
    local first_line
    first_line="$(echo "$fatals" | head -n1 | cut -d: -f1)"
    echo "首个致命错误上下文：" >&2
    _print_context "$logfile" "$first_line" 10 20 >&2
    echo "----------------------------------------" >&2
    local summ
    summ="$(error_summary "$logfile")"
    warn "致命错误摘要已写入：$summ"
    return 1
  fi
  return 0
}

_scan_log_for_errors_and_warn() {
  local logfile="$1"
  local errs
  errs="$(_extract_errors "$logfile" | head -n 200)" || true
  if [[ -n "$errs" ]]; then
    warn "检测到错误/警告样式输出（供排查参考，但不一定致命）："
    echo "----------------------------------------" >&2
    echo "$errs" >&2
    echo "----------------------------------------" >&2
    local summ
    summ="$(error_summary "$logfile")"
    warn "错误摘要已写入：$summ"
  fi
}

# -------------------- 修正后的 Core wrapper: run --------------------
run() {
  local desc="$1"; shift
  local logfile="$LOG_DIR/$(_sanitize "$desc").log"
  info "$desc"
  {
    echo "[$(date)] CMD: $*"
    echo "----------------------------------------"
  } >"$logfile"

  # --- 临时禁用 errexit 与 ERR trap（保存并恢复） ---
  local old_trap
  old_trap="$(trap -p ERR || true)"   # 保存当前 ERR trap（如果有）
  trap - ERR                           # 暂时清除 ERR trap
  set +e                               # 关闭 errexit，确保后续命令失败可被捕获

  # 执行命令并捕获返回码（不会让 shell 退出）
  local rc=0
  if ! "$@" >>"$logfile" 2>&1; then
    rc=$?
  else
    rc=0
  fi

  # 恢复 ERR trap 与 errexit
  if [[ -n "$old_trap" ]]; then
    eval "$old_trap" || true
  else
    trap - ERR
  fi
  set -e

  if [[ $rc -ne 0 ]]; then
    echo >&2
    warn "步骤失败：$desc"
    warn "退出码：$rc"
    echo "----------------------------------------" >&2

    local errors
    errors="$(_extract_errors "$logfile" | head -n 200)" || true
    if [[ -n "$errors" ]]; then
      warn "关键错误摘要（全文 grep）:"
      echo "$errors" >&2
    else
      warn "未在日志中找到匹配 ERROR_REGEX 的行，打印最后 ${LOG_TAIL_LINES} 行以供调试："
      tail -n "$LOG_TAIL_LINES" "$logfile" >&2
    fi

    echo "----------------------------------------" >&2
    local summary
    summary="$(error_summary "$logfile")"
    die "完整日志见：$logfile ; 摘要见：$summary" "$rc"
  fi

  if [[ "${FAIL_ON_FATAL_IN_SUCCESS:-0}" == "1" ]]; then
    if ! _scan_log_for_fatal_and_maybe_fail "$logfile"; then
      die "失败：在 $desc 日志中检测到致命关键字（尽管命令返回0）"
    fi
  fi

  _scan_log_for_errors_and_warn "$logfile" || true

  info "完成：$desc"
}

# -------------------- post_check / aggregate / group / enable_strict_mode (unchanged) --------------------
post_check() {
  local logfile="$1"
  if [[ ! -f "$logfile" ]]; then
    warn "post_check: 日志文件不存在：$logfile"
    return 0
  fi

  if ! _scan_log_for_fatal_and_maybe_fail "$logfile"; then
    die "post_check: 在日志中检测到致命关键字"
  fi

  _scan_log_for_errors_and_warn "$logfile" || true
}

aggregate_all_summaries() {
  local out="$LOG_DIR/aggregate_summary-$(date +%Y%m%d-%H%M%S).txt"
  echo "AGGREGATE ERROR SUMMARY - $(date)" >"$out"
  for f in "$LOG_DIR"/*.log; do
    [[ -f "$f" ]] || continue
    echo >>"$out"
    echo "----- $(basename "$f") -----" >>"$out"
    _extract_errors "$f" | head -n 50 >>"$out" || true
  done
  echo "$out"
}

group() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::group::$*"
  else
    info "== $* =="
  fi
}
endgroup() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::endgroup::"
  fi
}

enable_strict_mode() {
  trap 'die "脚本在第 $LINENO 行异常退出"' ERR
  set -o errtrace
}


# export_versions_from_json
# Usage:
#   export_versions_from_json <versions_json> [<gcc_version>] [mode] [outpath]
# Params:
#   versions_json - path to the JSON file (required)
#   gcc_version   - desired GCC version key (optional; default: $GCC_VERSION or first key)
#   mode          - one of: env | outputs | file   (default: env)
#   outpath       - when mode=file, write selected JSON to this path (default: $GITHUB_WORKSPACE/versions.selected.json)
#
# Examples:
#   export_versions_from_json scripts/versions.json 13.2.0 env
#   export_versions_from_json scripts/versions.json 13.2.0 outputs
#   export_versions_from_json scripts/versions.json 13.2.0 file /tmp/vers.json
export_versions_from_json() {
  local versions_file="${1:?versions_file is required}"
  local requested_ver="${2:-${GCC_VERSION:-}}"
  local mode="${3:-env}"
  local outpath="${4:-${GITHUB_WORKSPACE:-.}/versions.selected.json}"

  # tools
  command -v jq >/dev/null 2>&1 || { echo "jq is required but not found" >&2; return 2; }
  command -v base64 >/dev/null 2>&1 || { echo "base64 is required but not found" >&2; return 2; }

  if [[ ! -f "$versions_file" ]]; then
    echo "Versions file not found: $versions_file" >&2
    return 3
  fi

  # find version
  local ver
  if [[ -n "$requested_ver" ]] && jq -e --arg v "$requested_ver" '.gcc_versions[$v]' "$versions_file" >/dev/null 2>&1; then
    ver="$requested_ver"
  else
    if [[ -n "$requested_ver" ]]; then
      echo "Warning: requested version '$requested_ver' not found in $versions_file; falling back to first available." >&2
    fi
    ver="$(jq -r '.gcc_versions | keys_unsorted[0]' "$versions_file")"
    if [[ -z "$ver" || "$ver" == "null" ]]; then
      echo "Error: no gcc_versions entries found in $versions_file" >&2
      return 4
    fi
  fi

  # extract object for selected version into a temp file
  local tmp selected_json
  tmp="$(mktemp)"
  jq -r --arg v "$ver" '.gcc_versions[$v]' "$versions_file" >"$tmp" || { echo "Failed to extract version object" >&2; rm -f "$tmp"; return 5; }

  # Write selected JSON if requested (mode=file or always write to outpath)
  if [[ "$mode" == "file" ]]; then
    mkdir -p "$(dirname "$outpath")" 2>/dev/null || true
    mv "$tmp" "$outpath"
    echo "WROTE_SELECTED_JSON=${outpath}" >&2
    # If running in GitHub Actions, export path as step output
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "versions_file=${outpath}" >>"$GITHUB_OUTPUT"
      echo "gcc-version=${ver}" >>"$GITHUB_OUTPUT"
    fi
    return 0
  fi

  # iterate entries robustly (use base64 to avoid issues with special chars)
  # jq -> base64 of each entry ({"key":..,"value":..})
  while IFS= read -r entry_b64; do
    # decode
    local entry_json key raw_val norm_key
    entry_json="$(echo "$entry_b64" | base64 --decode)"
    key="$(echo "$entry_json" | jq -r '.key')"
    raw_val="$(echo "$entry_json" | jq -r '.value')"

    # normalize key => valid env var: non-alnum => _, to lowercase
    norm_key="$(echo "$key" | sed 's/[^A-Za-z0-9_]/_/g' | tr '[:lower:]' '[:upper:]')"

    case "$mode" in
      env)
        # write to GITHUB_ENV if present, else export in current shell
        if [[ -n "${GITHUB_ENV:-}" ]]; then
          printf '%s=%s\n' "$norm_key" "$raw_val" >>"$GITHUB_ENV"
        else
          # fallback: export for the current shell (note: won't persist across separate steps)
          export "$norm_key"="$raw_val"
        fi
        ;;
      outputs)
        # write each as a step output: name=value
        # GitHub Actions requires "name=value" appended to $GITHUB_OUTPUT
        if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
          # ensure no literal newlines in value for GITHUB_OUTPUT (versions usually don't have them)
          # If multiline occurs, we escape it as json here
          if [[ "$raw_val" == *$'\n'* ]]; then
            # base64-encode multiline values to avoid truncation; consumer must decode
            b64="$(printf '%s' "$raw_val" | base64 -w0)"
            printf '%s=%s\n' "$norm_key" "$b64" >>"$GITHUB_OUTPUT"
            # also emit a companion var telling it's base64 encoded
            printf '%s__b64=1\n' "$norm_key" >>"$GITHUB_OUTPUT"
          else
            printf '%s=%s\n' "$norm_key" "$raw_val" >>"$GITHUB_OUTPUT"
          fi
        else
          # fallback: print to stdout in "key=value" form
          printf '%s=%s\n' "$norm_key" "$raw_val"
        fi
        ;;
      *)
        echo "Unknown mode: $mode (supported: env, outputs, file)" >&2
        rm -f "$tmp"
        return 6
        ;;
    esac
  done < <(jq -c -r 'to_entries[] | @base64' "$tmp")

  # also export gcc-version for convenience
  if [[ "$mode" == "env" ]]; then
    if [[ -n "${GITHUB_ENV:-}" ]]; then
      echo "gcc_version=${ver}" >>"$GITHUB_ENV"
    else
      export gcc_version="$ver"
    fi
  elif [[ "$mode" == "outputs" ]]; then
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "gcc-version=${ver}" >>"$GITHUB_OUTPUT"
    else
      echo "gcc-version=${ver}"
    fi
  fi

  rm -f "$tmp" 2>/dev/null || true
  return 0
}


# ----------------- 通用下载/URL 组装函数（放在 step 内） -----------------

# 基本 curl 下载（带重试、断点续传、原子 .part 临时文件）
_curl_download() {
  local url="$1" out="$2" logf="$3" tmp="${out}.part"
  mkdir -p "$(dirname "$out")"
  echo "TRY: $url" >>"$logf"
  # curl 的 stderr 会被追加到 logfile，以便排查（--fail 保证 404 返回非0）
  if curl --fail -L --retry 3 --retry-delay 2 -C - -sS "$url" -o "$tmp" 2>>"$logf"; then
    mv "$tmp" "$out"
    echo "OK: $out" >>"$logf"
    return 0
  else
    # 保证未留下残留.part
    rm -f "$tmp"
    echo "FAIL: $url (curl failed, see above)" >>"$logf"
    return 1
  fi
}

# ----- get_version：兼容不同命名（处理 '-' -> '_'） -----
get_version() {
  local pkg="$1"
  local lc uc key key2 key2_uc val
  lc="$(echo "$pkg" | tr '[:upper:]' '[:lower:]')"
  uc="$(echo "$pkg" | tr '[:lower:]' '[:upper:]')"
  key2="${lc//-/_}"
  key2_uc="${uc//-/_}"

  for key in "$lc" "$key2" "$uc" "$key2_uc" "${lc}_version" "${key2}_version" "${uc}_VERSION" "${key2_uc}_VERSION"; do
    val="${!key:-}"
    if [[ -n "$val" ]]; then
      printf '%s' "$val"
      return 0
    fi
  done
  return 1
}

# ----- sqlite digits: major*1000000 + minor*10000 + patch*100 (e.g. 3.42.0 -> 3420000) -----
sqlite_digits() {
  local v="$1"
  # split by dots
  IFS=. read -r maj min pat <<<"$v"
  maj=${maj:-0}; min=${min:-0}; pat=${pat:-0}
  # numeric: maj*1_000_000 + min*10_000 + pat*100
  printf '%d' $(( maj * 1000000 + min * 10000 + pat * 100 ))
}

# 扩展优先级
_GNU_EXTS=(tar.xz tar.gz tgz tar.bz2 tar)

# 模板（可扩展）
declare -A PKG_TEMPLATES
for p in readline ncurses make gdb gdbm libgdbm binutils libiconv libffi; do
  PKG_TEMPLATES["$p"]='{{GNU}}/'"$p"'/'"$p"'-%s.%s'
done
PKG_TEMPLATES["gcc"]='{{GNU}}/gcc/gcc-%s.%s'
PKG_TEMPLATES["zlib"]='https://zlib.net/fossils/zlib-%s.%s'
PKG_TEMPLATES["mingw-w64"]='{{MINGW}}/v%s.%s'
PKG_TEMPLATES["libgnurx"]='{{GNURX_FALLBACK}}'
PKG_TEMPLATES["expat"]='{{EXPAT_RELEASE}}'
PKG_TEMPLATES["python"]='https://www.python.org/ftp/python/%s/Python-%s.%s'
PKG_TEMPLATES["sqlite"]='{{SQLITE_AUTOCONF}}'
PKG_TEMPLATES["openssl"]='https://www.openssl.org/source/openssl-%s.%s'
PKG_TEMPLATES["xz"]='https://tukaani.org/xz/xz-%s.%s'
PKG_TEMPLATES["bzip2"]='https://sourceware.org/pub/bzip2/bzip2-%s.%s'
PKG_TEMPLATES["tcl"]='https://prdownloads.sourceforge.net/tcl/tcl%s-src.%s'
PKG_TEMPLATES["tk"]='https://prdownloads.sourceforge.net/tcl/tk%s-src.%s'

# ----- download_by_name：尝试并把每次尝试与错误写入指定 log 文件 -----
# Usage: download_by_name <pkg>
#   on success: prints downloaded path to stdout
#   on failure: prints nothing and returns non-zero (errors logged to logfile)
download_by_name() {
  local pkg="$1"
  local ver template tmpl url out try ext digits logf
  logf="${LOG_DIR}/下载_${pkg}.log"

  if ! ver="$(get_version "$pkg")"; then
    echo "ERROR: version for '${pkg}' not found in environment" >>"$logf"
    echo "ERROR: version for '${pkg}' not found in environment" >&2
    return 2
  fi

  template="${PKG_TEMPLATES[$pkg]:-}"

  echo "DOWNLOAD START: ${pkg} ${ver}" >"$logf"

  case "$pkg" in
    libgnurx)
      out="${SOURCE_CODE_DIR}/libgnurx-${ver}.tar.gz"
      try="https://github.com/TimothyGu/libgnurx/archive/refs/tags/v${ver}.tar.gz"
      if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      try="https://github.com/TimothyGu/libgnurx/archive/refs/tags/${ver}.tar.gz"
      if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      echo "ERROR: libgnurx download failed for ${ver}" >>"$logf"
      echo "ERROR: libgnurx download failed for ${ver}" >&2
      return 1
      ;;
    expat)
      local tag="R_${ver//./_}"
      out="${SOURCE_CODE_DIR}/expat-${ver}.tar.gz"
      try="https://github.com/libexpat/libexpat/releases/download/${tag}/expat-${ver}.tar.gz"
      if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      echo "ERROR: expat download failed for ${ver}" >>"$logf"
      echo "ERROR: expat download failed for ${ver}" >&2
      return 1
      ;;
    sqlite)
      digits="$(sqlite_digits "$ver")"
      out="${SOURCE_CODE_DIR}/sqlite-autoconf-${digits}-0.tar.gz"
      try="https://www.sqlite.org/2023/sqlite-autoconf-${digits}-0.tar.gz"
      # try 2023 path then 2024 as fallback
      if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      try="https://www.sqlite.org/2024/sqlite-autoconf-${digits}-0.tar.gz"
      if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      echo "ERROR: sqlite download failed for ${ver}" >>"$logf"
      echo "ERROR: sqlite download failed for ${ver}" >&2
      return 1
      ;;
    mingw-w64)
      for ext in "${_GNU_EXTS[@]}"; do
        out="${SOURCE_CODE_DIR}/mingw-w64-v${ver}.${ext}"
        try="${MINGW_BASE_URL}/v${ver}.${ext}"
        if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
        try="${MINGW_BASE_URL}/${ver}.${ext}"
        if _curl_download "$try" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      done
      echo "ERROR: mingw-w64 download failed for ${ver}" >>"$logf"
      echo "ERROR: mingw-w64 download failed for ${ver}" >&2
      return 1
      ;;
    *)
      if [[ -n "$template" ]]; then
        tmpl="${template//\{\{GNU\}\}/${GNU_BASE_URL}}"
        tmpl="${tmpl//\{\{MINGW\}\}/${MINGW_BASE_URL}}"
        for ext in "${_GNU_EXTS[@]}"; do
          if [[ "$(grep -o '%s' <<<"$tmpl" | wc -l)" -ge 2 ]]; then
            url="$(printf "$tmpl" "$ver" "$ext")"
            out="${SOURCE_CODE_DIR}/${pkg}-${ver}.${ext}"
          else
            url="$(printf "$tmpl" "$ver")"
            out="${SOURCE_CODE_DIR}/${pkg}-${ver}.${ext}"
          fi
          if _curl_download "$url" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
        done
      fi

      # fallback common GNU urls
      for ext in "${_GNU_EXTS[@]}"; do
        url="${GNU_BASE_URL}/${pkg}/${pkg}-${ver}.${ext}"
        out="${SOURCE_CODE_DIR}/${pkg}-${ver}.${ext}"
        if _curl_download "$url" "$out" "$logf"; then printf '%s' "$out"; return 0; fi
      done

      echo "ERROR: download failed for ${pkg} ${ver} (tried common GNU urls)" >>"$logf"
      echo "ERROR: download failed for ${pkg} ${ver} (tried common GNU urls)" >&2
      return 1
      ;;
  esac
}