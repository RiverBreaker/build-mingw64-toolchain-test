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
