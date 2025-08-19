# function.sh - small helper functions for path normalization (MSYS2 / GitHub Actions)
# Safe to 'source' from other scripts. Does NOT change errexit/pipefail of caller.
#
# Usage: source /path/to/function.sh
#        to_posix_abs "D:\a\repo"   -> /d/a/repo
#        WORKDIR="$(to_posix_abs "$GITHUB_WORKSPACE")"

# guard against double-sourcing
if [ "${_FUNCTION_SH_LOADED:-}" = "1" ]; then
  return 0
fi
_FUNCTION_SH_LOADED=1

# --------------------------
# to_posix_abs: turn arbitrary path into POSIX-style absolute path (/d/...)
# --------------------------
to_posix_abs() {
  local raw="$1"
  # empty -> pwd
  if [ -z "$raw" ]; then
    raw="$(pwd)"
  fi

  # 1) prefer cygpath if available (most reliable in MSYS2)
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$raw"
    return
  fi

  # 2) fallback to realpath -m then normalize drive letter if present
  if command -v realpath >/dev/null 2>&1; then
    local rp
    rp="$(realpath -m "$raw" 2>/dev/null || echo "$raw")"
    rp="${rp//\\//}"   # backslash -> slash
    if [[ "$rp" =~ ^([A-Za-z]):(/.*)?$ ]]; then
      local drive="${BASH_REMATCH[1],,}"
      local rest="${BASH_REMATCH[2]:-}"
      rest="${rest#/}"
      echo "/$drive/$rest"
    else
      echo "$rp"
    fi
    return
  fi

  # 3) last-resort string transform
  raw="${raw//\\//}"
  if [[ "$raw" =~ ^([A-Za-z]):(/.*)?$ ]]; then
    local drive="${BASH_REMATCH[1],,}"
    local rest="${BASH_REMATCH[2]:-}"
    rest="${rest#/}"
    echo "/$drive/$rest"
  else
    echo "$raw"
  fi
}

# --------------------------
# normalize_var: (optional helper)
# Usage: normalize_var VAR_NAME
# This will read $VAR_NAME, convert with to_posix_abs, then export VAR_NAME with normalized value.
# Example: normalize_var GITHUB_WORKSPACE
# --------------------------
normalize_var() {
  local varname="$1"
  if [ -z "$varname" ]; then
    return 1
  fi
  # indirect expansion to get variable value
  local val="${!varname:-}"
  local normalized
  normalized="$(to_posix_abs "$val")"
  # set and export the variable in caller context
  # note: eval is used to set variable by name
  eval "export $varname=\"\$normalized\""
}

# Optionally export the functions to sub-shells if you expect them to be used in child bash processes
# export -f to_posix_abs normalize_var
