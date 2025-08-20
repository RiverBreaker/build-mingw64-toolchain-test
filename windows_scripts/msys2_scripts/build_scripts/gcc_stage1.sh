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
export BUILD="$(/usr/bin/config.guess 2>/dev/null || echo "$(uname -m)-pc-msys")"
export HOST=x86_64-w64-mingw32
export PATH=$PATH:$PREFIX/bin

if [ -d $BUILD_DIR/build-binutils ]; then
    rm -rf $BUILD_DIR/build-binutils
    echo "remove $BUILD_DIR/build-binutils"
fi
if [ -d $BUILD_DIR/build-gcc1 ]; then
    rm -rf $BUILD_DIR/build-gcc1
    echo "remove $BUILD_DIR/build-gcc1"
fi
mkdir -p $BUILD_DIR/build-gcc1
echo "mkdir $BUILD_DIR/build-gcc1"

gcc_src=$(realpath --relative-to="${BUILD_DIR}/build-gcc1" "${SRC_DIR}/gcc")

cd $BUILD_DIR/build-gcc1
echo "Configure mingw gcc stage 1 starting..."
${gcc_src}/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$BUILD \
    --target=$TARGET \
    --program-prefix=$TARGET- \
    --disable-nls \
    --disable-lto \
    --disable-multilib \
    --disable-libssp \
    --disable-libmudflap \
    --disable-libgomp \
    --disable-libgcc \
    --disable-libstdc++-v3 \
    --disable-libatomic \
    --disable-libvtv \
    --disable-libquadmath \
    --enable-sjlj-exceptions \
    --enable-languages=c,c++ \
    --enable-version-specific-runtime-libs \
    --enable-decimal-float=yes \
    --enable-tls \
    --enable-fully-dynamic-string \
    --with-gnu-ld \
    --with-gnu-as \
    --with-libiconv \
    --with-system-zlib \
    --without-dwarf2 \
    --with-sysroot=$PREFIX/$TARGET \
    --with-local-prefix=$PREFIX/local \
    --with-gmp=$PREFIX \
    --with-mpfr=$PREFIX \
    --with-mpc=$PREFIX \
    --with-isl=$PREFIX
echo "Configure gcc stage 1 done"
make -j1 && make install
echo "Build gcc stage 1 done"

ls $PREFIX/bin/$TARGET-*

# Post-installation verification
if [ -x "$PREFIX/bin/$TARGET-gcc" ]; then
    echo "GCC stage 1 installation verified successfully."
else
    echo "GCC stage 1 installation verification failed." >&2
fi

sleep 30
if [ -d $BUILD_DIR/build-gcc1 ]; then
    rm -rf $BUILD_DIR/build-gcc1
    echo "remove $BUILD_DIR/build-gcc1"
fi