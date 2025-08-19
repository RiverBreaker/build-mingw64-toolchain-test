if [ $CRT = "ucrt" ]; then
    export MSYSTEM="UCRT64"
else
    export MSYSTEM="MINGW64"
fi
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
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

if [ ! -d $BUILD_DIR/build-mingw-headers ]; then
    mkdir $BUILD_DIR/build-mingw-headers
    echo "mkdir $BUILD_DIR/build-mingw-headers"
fi
cd $BUILD_DIR/build-mingw-headers
# Build headers
echo "Configure win mingw headers starting..."
$SRC_DIR/mingw-w64/mingw-w64-headers/configure \
    --prefix=$PREFIX/$TARGET \
    --build=$BUILD \
    --target=$TARGET \
    --host=$HOST \
    --enable-idl
echo "Configure headers completed."
make -j1 && make install
echo "Build headers completed."

sleep 30
if [ -d $BUILD_DIR/build-mingw-headers ]; then
    rm -rf $BUILD_DIR/build-mingw-headers
    echo "remove $BUILD_DIR/build-mingw-headers"
fi
