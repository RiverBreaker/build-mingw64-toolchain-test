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
FUNCTION_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
source "$FUNCTION_DIR/function/win_2_posix_abs.sh"
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

cd $BUILD_DIR
for d in build-mingw-libmangle build-mingw-gendef build-mingw-genidl build-mingw-genpeimg build-mingw-widl; do
    if [ ! -d $BUILD_DIR/$d ]; then
        mkdir $BUILD_DIR/$d
    fi
done

cd $BUILD_DIR/build-mingw-libmangle
echo "Configure win mingw libmangle starting..."
$SRC_DIR/mingw-w64/mingw-w64-libraries/libmangle/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST
echo "Configure libmangle completed."
make -j1 && make install
echo "Build libmangle completed."

# Build gendef
cd $BUILD_DIR/build-mingw-gendef
echo "Configure win mingw gendef starting..."
$SRC_DIR/mingw-w64/mingw-w64-tools/gendef/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --with-libmangle=$PREFIX
echo "Configure gendef completed."
make -j1 && make install
echo "Build gendef completed."

# Build genidl
cd $BUILD_DIR/build-mingw-genidl
echo "Configure win mingw genidl starting..."
$SRC_DIR/mingw-w64/mingw-w64-tools/genidl/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST
echo "Configure genidl completed."
make -j1 && make install
echo "Build genidl completed."

# Build genpeimg
cd $BUILD_DIR/build-mingw-genpeimg
echo "Configure win mingw genpeimg starting..."
$SRC_DIR/mingw-w64/mingw-w64-tools/genpeimg/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST
echo "Configure genpeimg completed."
make -j1 && make install
echo "Build genpeimg completed."

# Build widl
cd $BUILD_DIR/build-mingw-widl
echo "Configure win mingw widl starting..."
ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes $SRC_DIR/mingw-w64/mingw-w64-tools/widl/configure \
        --prefix=$PREFIX \
        --build=$BUILD \
        --host=$HOST \
        --target=$TARGET \
        --program-prefix=""
echo "Configure widl completed."
make -j1 && make install
echo "Build widl completed."

sleep 30
for d in build-mingw-libmangle build-mingw-gendef build-mingw-genidl build-mingw-genpeimg build-mingw-widl; do
    if [ -d $BUILD_DIR/$d ]; then
        rm -rf $BUILD_DIR/$d && echo "remove $BUILD_DIR/$d"
    fi
done
