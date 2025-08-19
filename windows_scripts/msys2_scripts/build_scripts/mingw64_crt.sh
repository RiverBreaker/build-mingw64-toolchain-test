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
source "$FUNCTION_DIR/../function/win_2_posix_abs.sh"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
normalize_var WORKDIR
export SRC_DIR="${WORKDIR}/src"
export BUILD_DIR="${WORKDIR}/build-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
export PREFIX="${WORKDIR}/mingw64-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
export TARGET=x86_64-w64-mingw32
export BUILD="$(gcc -dumpmachine)"
export HOST=x86_64-w64-mingw32
export PATH=$PREFIX/bin:$PATH
# Set cross-compiler environment variables
export CC_FOR_BUILD=gcc
export CXX_FOR_BUILD=g++
export CC=$TARGET-gcc
export CXX=$TARGET-g++
export AR=$TARGET-ar
export RANLIB=$TARGET-ranlib
export STRIP=$TARGET-strip
export AS=$TARGET-as
export DLLTOOL=$TARGET-dlltool
if [ ! -d $BUILD_DIR/build-mingw-crt ]; then
    mkdir $BUILD_DIR/build-mingw-crt
fi
cd $BUILD_DIR/build-mingw-crt
# Build crt
echo "Configure win mingw crt starting..."
AR="$AR" \
AS="$AS" \
CC="$CC" \
CXX="$CXX" \
DLLTOOL="$DLLTOOL" \
RANLIB="$RANLIB" \
    $SRC_DIR/mingw-w64/mingw-w64-crt/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --disable-w32api \
    --disable-lib32 \
    --enable-lib64 \
    --enable-private-exports
echo "Configure crt completed."
make -j1 && make install
echo "Build crt completed."

sleep 30
if [ -d $BUILD_DIR/build-mingw-crt ]; then
    rm -rf $BUILD_DIR/build-mingw-crt
    echo "remove $BUILD_DIR/build-mingw-crt"
fi