#!/usr/bin/env bash
# functions.sh - CI-friendly logging & multi-error-aware helpers
# Usage: source functions.sh
# --------------------------------------------------------------

set -u
set -o pipefail

# -------------------- Configurable variables --------------------
: "${LOG_DIR:=logs}"
: "${LOG_TAIL_LINES:=50}"
# 全文认为“错误”的关键字（case-insensitive, extended regex）
: "${ERROR_REGEX:=error:|fatal|undefined reference|collect2:|internal compiler error|segmentation fault|make: \\*\\*\\*|configure: error}"
# 被认为“致命”的关键字（会导致脚本失败），可按需扩展
: "${FATAL_REGEX:=internal compiler error|segmentation fault|undefined reference|internal compiler error:}"
# 需要忽略的模式（比如已知的 mingw-w64 头文件误报），留空则不过滤
: "${IGNORE_REGEX:=array subscript 0 is outside array bounds}"
# 如果为 1，则在成功命令后仍会扫描 fatal patterns 并失败（保护性检查）
: "${FAIL_ON_FATAL_IN_SUCCESS:=1}"

mkdir -p "$LOG_DIR"

# -------------------- Color / timestamp --------------------
if [[ -t 1 ]]; then
  RED='\033[31m'; YELLOW='\033[33m'; BLUE='\033[34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

timestamp() { date +"%H:%M:%S"; }

info()  { echo -e "${BLUE}[$(timestamp)] INFO:${RESET} $*"; }
warn()  { echo -e "${YELLOW}[$(timestamp)] WARN:${RESET} $*" >&2; }
die()   { local msg="$1"; local code="${2:-1}"; echo -e "${RED}${BOLD}[$(timestamp)] ERROR:${RESET} $msg" >&2; exit "$code"; }

# -------------------- Internal helpers --------------------
_sanitize() { echo "$*" | tr ' /:|()' '___' | tr -s '_' ; }

# 返回匹配到的 error lines（带行号），应用 IGNORE_REGEX 过滤
_extract_errors() {
  local logfile="$1"
  if [[ -z "$IGNORE_REGEX" ]]; then
    grep -nEi -- "$ERROR_REGEX" "$logfile" || true
  else
    grep -nEi -- "$ERROR_REGEX" "$logfile" | grep -vEi -- "$IGNORE_REGEX" || true
  fi
}

# 返回匹配到的 fatal lines（带行号），应用 IGNORE_REGEX 过滤
_extract_fatals() {
  local logfile="$1"
  if [[ -z "$IGNORE_REGEX" ]]; then
    grep -nEi -- "$FATAL_REGEX" "$logfile" || true
  else
    grep -nEi -- "$FATAL_REGEX" "$logfile" | grep -vEi -- "$IGNORE_REGEX" || true
  fi
}

# 给定 logfile 与某行号，打印上下文（前后 lines）
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

# 生成 error summary 文件（returns path）
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

# 扫描 logfile，若发现 fatal，则打印并返回 1（失败），否则返回 0
_scan_log_for_fatal_and_maybe_fail() {
  local logfile="$1"
  # find fatal matches
  local fatals
  fatals="$(_extract_fatals "$logfile" | head -n 100)" || true
  if [[ -n "$fatals" ]]; then
    warn "检测到致命错误（即使命令返回 0）："
    echo "----------------------------------------" >&2
    echo "$fatals" >&2
    echo "----------------------------------------" >&2
    # show context of first fatal
    local first_line
    first_line="$(echo "$fatals" | head -n1 | cut -d: -f1)"
    echo "首个致命错误上下文：" >&2
    _print_context "$logfile" "$first_line" 10 20 >&2
    echo "----------------------------------------" >&2
    # produce summary
    local summ
    summ="$(error_summary "$logfile")"
    warn "致命错误摘要已写入：$summ"
    return 1
  fi
  return 0
}

# 扫描 logfile，若发现 error（非致命），打印摘要但不立即失败
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

# -------------------- Core wrapper: run --------------------
run() {
  local desc="$1"; shift
  local logfile="$LOG_DIR/$(_sanitize "$desc").log"
  info "$desc"
  {
    echo "[$(date)] CMD: $*"
    echo "----------------------------------------"
  } >"$logfile"

  # Execute command, capture exit code
  "$@" >>"$logfile" 2>&1
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    echo >&2
    warn "步骤失败：$desc"
    warn "退出码：$rc"
    echo "----------------------------------------" >&2

    # 先把关键错误摘出来（尽量把真正的 error 摘出）
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

  # 如果命令返回 0，仍检查是否有 fatal patterns（防止 configure 等“吞失真”）
  if [[ "${FAIL_ON_FATAL_IN_SUCCESS:-0}" == "1" ]]; then
    if ! _scan_log_for_fatal_and_maybe_fail "$logfile"; then
      die "失败：在 $desc 日志中检测到致命关键字（尽管命令返回0）"
    fi
  fi

  # 同时给出非致命 errors 的警告摘要（不退出）
  _scan_log_for_errors_and_warn "$logfile" || true

  # 成功时只输出 info（轻量）
  info "完成：$desc"
}

# -------------------- Convenience: post_check --------------------
# 可在单独步骤后手动调用，检测 logfile 中的问题（用于那些不是 run 包装的命令）
post_check() {
  local logfile="$1"
  if [[ ! -f "$logfile" ]]; then
    warn "post_check: 日志文件不存在：$logfile"
    return 0
  fi

  # 若有 fatals -> fail
  if ! _scan_log_for_fatal_and_maybe_fail "$logfile"; then
    die "post_check: 在日志中检测到致命关键字"
  fi

  # 若有 errors -> warn + make summary
  _scan_log_for_errors_and_warn "$logfile" || true
}

# -------------------- Aggregate: scan all logs --------------------
# 在 CI 结束时运行，生成所有日志的 summary 档案
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

# -------------------- GitHub Actions group support --------------------
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

# -------------------- Strict mode helper --------------------
enable_strict_mode() {
  trap 'die "脚本在第 $LINENO 行异常退出"' ERR
  set -o errtrace
}
