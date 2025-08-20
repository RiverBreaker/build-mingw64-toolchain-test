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
export PATH=$PREFIX/bin:$PATH

export CC=$TARGET-gcc
export CXX=$TARGET-g++
export AR=$TARGET-ar
export RANLIB=$TARGET-ranlib
export STRIP=$TARGET-strip
export AS=$TARGET-as
export DLLTOOL=$TARGET-dlltool
export SYSROOT="$PREFIX/$TARGET"
export CPPFLAGS_FOR_TARGET="-I${PREFIX}/include -I${SYSROOT}/include"
export CFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET"
export CXXFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET"
export LDFLAGS_FOR_TARGET="-L${PREFIX}/lib -L${SYSROOT}/lib"

if [ ! -d $BUILD_DIR/build-gdb ]; then
    mkdir -p $BUILD_DIR/build-gdb
    echo "mkdir $BUILD_DIR/build-gdb"
fi
gdb_src=$(realpath --relative-to="${BUILD_DIR}/build-gdb" "${SRC_DIR}/gdb")

echo "Configure mingw gdb starting..."
cd $BUILD_DIR/build-gdb
CPPFLAGS_FOR_TARGET="-I$PREFIX/$TARGET/include -I$PREFIX/include" \
LDFLAGS_FOR_TARGET="-L$PREFIX/$TARGET/lib -L$PREFIX/lib" \
${gdb_src}/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET \
    --enable-static \
    --enable-shared \
    --disable-nls \
    --enable-ld \
    --disable-lto
echo "Configure GDB done."
make -j1 && make install
echo "Build GDB done."

# Post-installation verification
if [ -x "$PREFIX/bin/$TARGET-gdb" ]; then
    echo "GDB installation verified successfully."
else
    echo "GDB installation verification failed." >&2
fi
# Clean up
if [ -d $BUILD_DIR/build-gdb ]; then
    rm -rf $BUILD_DIR/build-gdb
    echo "remove $BUILD_DIR/build-gdb"
fi