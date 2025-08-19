if [ $CRT = "ucrt" ]; then
    export MSYSTEM="UCRT64"
else
    export MSYSTEM="MINGW64"
fi
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
if command -v realpath >/dev/null 2>&1; then
    WORKDIR="$(realpath -m "$WORKDIR")"
elif command -v cygpath >/dev/null 2>&1; then
    WORKDIR="$(cygpath -u "$WORKDIR")"
else
    WORKDIR="$(pwd)"
fi
export SRC_DIR="${WORKDIR}/src"
export BUILD_DIR="${WORKDIR}/build-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
export PREFIX="${WORKDIR}/mingw64-${ARCH}-${THREAD}-${EXCEPTION}-${CRT}"
if command -v realpath >/dev/null 2>&1; then
    PREFIX="$(realpath -m "$PREFIX")"
elif command -v cygpath >/dev/null 2>&1; then
    PREFIX="$(cygpath -u "$PREFIX")"
else
    PREFIX="$PREFIX"
fi
export TARGET=x86_64-w64-mingw32
export BUILD="$(gcc -dumpmachine)"
export HOST=x86_64-w64-mingw32

if [ ! -d $BUILD_DIR/build-binutils ]; then
    mkdir -p $BUILD_DIR/build-binutils
    echo "mkdir $BUILD_DIR/build-binutils"
fi

binutils_src="$(realpath -m "${SRC_DIR}/binutils")"

cd $BUILD_DIR/build-binutils
echo "Configure gnu mingw binutils starting..."
${binutils_src}/configure \
    --target=$TARGET \
    --build=$BUILD \
    --prefix=$PREFIX \
    --with-sysroot=$PREFIX/$TARGET \
    --enable-static \
    --disable-shared \
    --disable-gdb \
    --disable-nls \
    --enable-ld \
    --disable-lto 
echo "Configure Binutils completed."
# mkdir -p $BUILD_TEMP/build-gnu-binutils/gas/doc
make -j1 && make install
echo "Build Binutils completed."
ls $PREFIX/bin

# Post-installation verification
if [ -x "$PREFIX/bin/$TARGET-ld" ]; then
    echo "Binutils installation verified successfully."
else
    echo "Binutils installation verification failed." >&2
fi

sleep 30
if [ -d $BUILD_DIR/build-binutils ]; then
    rm -rf $BUILD_DIR/build-binutils
    echo "remove $BUILD_DIR/build-binutils"
fi