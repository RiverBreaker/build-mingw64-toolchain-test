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
export BUILD="$(gcc -dumpmachine)"
export HOST=x86_64-w64-mingw32

if [ ! -d $BUILD_DIR/build-readline ]; then
    mkdir -p $BUILD_DIR/build-readline
    echo "mkdir $BUILD_DIR/build-readline"
fi

cd $BUILD_DIR/build-readline
echo "Configure gnu mingw readline starting..."
${SRC_DIR}/readline/configure \
    --target=$TARGET \
    --build=$BUILD \
    --prefix=$PREFIX \
    --enable-static \
    --disable-shared \
    --disable-nls \
    --enable-ld \
    --disable-lto 
echo "Configure Binutils completed."
make -j1 && make install
echo "Build Binutils completed."

sleep 30
if [ -d $BUILD_DIR/build-readline ]; then
    rm -rf $BUILD_DIR/build-readline
    echo "remove $BUILD_DIR/build-readline"
fi