if [ "$ARCH" == "x86_64" ];then
    if [ "$CRT" == "ucrt" ];then
        export MSYSTEM=ucrt64
        export PATH="/ucrt64/bin:$PATH"
    else
        export MSYSTEM=mingw64
        export PATH="/mingw64/bin:$PATH"
    fi
else
    export MSYSTEM=mingw32
    export PATH="/mingw32/bin:$PATH"
fi
FUNCTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../patch"
source "$FUNCTION_DIR/../function/win_2_posix_abs.sh"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
normalize_var WORKDIR
export SRC_DIR="${WORKDIR}/src"
export BUILD_DIR="${WORKDIR}/build-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
export PREFIX="${WORKDIR}/mingw64-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
export TARGET=x86_64-w64-mingw32
export BUILD="$(/usr/bin/config.guess 2>/dev/null || echo "$(uname -m)-pc-msys")"
export HOST=x86_64-w64-mingw32

if [ ! -d $BUILD_DIR/build-binutils ]; then
    mkdir -p $BUILD_DIR/build-binutils
    echo "mkdir $BUILD_DIR/build-binutils"
fi

binutils_src="$(realpath -m "${SRC_DIR}/binutils")"

cd $BUILD_DIR/build-binutils
echo "Configure gnu mingw binutils starting..."
CFLAGS="-O2 -fcommon -Wno-error" \
${binutils_src}/configure \
    --target=$TARGET \
    --build=$BUILD \
    --prefix=$PREFIX \
    --with-sysroot=$PREFIX/$TARGET \
    --enable-static \
    --disable-shared \
    --disable-nls \
    --enable-ld \
    --disable-lto 
echo "Configure Binutils completed."
# mkdir -p $BUILD_TEMP/build-gnu-binutils/gas/doc
make -j1 && make install
echo "Build Binutils completed."
ls $PREFIX/bin

# Post-installation verification
if [ -x "$PREFIX/bin/ld" ]; then
    echo "Binutils installation verified successfully."
else
    echo "Binutils installation verification failed." >&2
fi

sleep 30
if [ -d $BUILD_DIR/build-binutils ]; then
    rm -rf $BUILD_DIR/build-binutils
    echo "remove $BUILD_DIR/build-binutils"
fi