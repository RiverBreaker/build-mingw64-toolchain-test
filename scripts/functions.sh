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

curl_download() {
  local url="$1"
  local output="$2"
  local filename="$(basename "$url")"

  curl -SsL "$url" -o "$output/$filename" || { echo "Failed to download $url" >&2; return 1; }
  if [[ ! -f "$output/$filename" ]]; then
    echo "下载文件找不到: $output/$filename，将重试" >&2
    curl -sSL "$url" -o "$output/$filename" || { echo "Failed to download $url" >&2; return 1; }
  fi
}

# 使用示例
# curl_download "$url" "$output_path"

# for d in ${pkg[@]} ;do
#  curl_download "${GNU_BASE_URL}/${d}/${d}-${ver}.tar.gz" "$output_path"
# done

# 错误处理函数
safe_rm() {
    if [[ -e "$1" ]]; then
        info "删除: $1"
        if ! rm -rf "$1"; then
            cleanup_and_die "删除失败: $1"
        fi
    fi
}

# 清理函数
cleanup_and_die() {
    rm -rf "$tmp_dir"
    die "${1:-操作失败}"
}

archive_extract() {
  local pkg_name="$1"
  local archive="$2"
  local output_dir="$3"
  local filename
  filename="$(basename "$archive")"

  local tmp_dir="${output_dir}/tmp_extract_$(date +%s%N)"
  mkdir -p "$tmp_dir"

  tar -xf "$archive" -C "$tmp_dir" || {
    echo "解压失败: $archive" >&2
    rm -rf "$tmp_dir"
    return 1
  }

  # 只找 tmp_dir 下的第一层子目录（排除 tmp_dir 本身）
  local extracted_dir
  extracted_dir=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -1)

  if [[ -z "$extracted_dir" ]]; then
    echo "错误：未找到解压后的目录: $archive" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  local dirname
  dirname="$(basename "$extracted_dir")"

  mv "$extracted_dir" "${output_dir}/${pkg_name}" || {
    echo "重命名失败: $dirname -> $pkg_name" >&2
    rm -rf "$tmp_dir"
    return 1
  }
  if [[ "${pkg_name}" == "gcc" ]]; then
    info "处理 GCC 依赖项"
    local dep_libs=("gmp" "mpfr" "mpc" "isl")

    # 进入GCC目录
    cd "${output_dir}/${pkg_name}" || cleanup_and_die "无法进入目录"

    # 下载依赖
    info "下载 GCC 先决条件"
    if ! ./contrib/download_prerequisites --directory="${output_dir}"; then
        cleanup_and_die "下载 GCC 先决条件失败"
    fi

    # 清理旧依赖目录
    info "清理${pkg_name}内部依赖目录"
    for d in "${dep_libs[@]}"; do
        safe_rm "${output_dir}/${pkg_name}/${d}"
    done

    # 返回并处理依赖
    cd "${output_dir}" || cleanup_and_die "无法返回目录"

    for p in "${dep_libs[@]}"; do
        # 删除压缩包
        for f in "${output_dir}/${p}-"*.tar.*; do
            [[ -f "$f" ]] && safe_rm "$f"
        done

        # 重命名目录
        shopt -s nullglob
        local dirs=("${output_dir}/${p}-"*/)
        shopt -u nullglob

        if [[ ${#dirs[@]} -eq 0 ]]; then
            warn "未找到 ${p} 目录，跳过"
            continue
        fi

        # 只处理第一个目录
        info "重命名 ${dirs[0]} 到 ${output_dir}/${p}"
        if ! mv "${dirs[0]}" "${output_dir}/${p}"; then
            cleanup_and_die "重命名 ${p} 失败"
        fi
    done
  fi

  rm -rf "$tmp_dir"
  rm -f "$archive"

  info "解压完成: ${archive} -> ${output_dir}/${pkg_name}"
}
