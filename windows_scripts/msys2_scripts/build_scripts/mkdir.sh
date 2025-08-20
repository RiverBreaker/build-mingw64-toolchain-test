FUNCTION_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
source "$FUNCTION_DIR/function/win_2_posix_abs.sh"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
normalize_var WORKDIR
SRC_DIR="${WORKDIR}/src"
BUILD_DIR="${WORKDIR}/build-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
PREFIX="${WORKDIR}/mingw64-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"

echo "Using WORKDIR: $WORKDIR"
echo "Preparing source dir: $SRC_DIR"
echo "Preparing build dir: $BUILD_DIR"
echo "Preparing install dir: $PREFIX"

for d in "$SRC_DIR" "$BUILD_DIR" "$PREFIX"; do
    if [ -d "$d" ]; then
        rm -rf "$d" && echo "✅ Removed old directory: $d"
    fi
    mkdir -p "$d" && echo "✅ Created directory: $d" || {
        echo "❌ Failed to create directory: $d" >&2
        exit 1
    }
done
find . -type f \( -o -name '*.sh' -o -name '*.patch' \) -print0 | xargs -0 dos2unix
