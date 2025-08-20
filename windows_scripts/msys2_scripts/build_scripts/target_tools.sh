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

for d in build-zlib build-libiconv; do
    if [ ! -d $BUILD_DIR/$d ]; then
        mkdir -p $BUILD_DIR/$d
        echo "mkdir $BUILD_DIR/$d"
    fi
done
echo "====================================================="
echo "=              Build zlib                           ="
echo "====================================================="
echo "Configure zlib starting..."
cd $BUILD_DIR/build-zlib
$SRC_DIR/zlib/configure --prefix=$PREFIX --static
echo "Build zlib starting..."
make -j1 && make install
echo "Build zlib completed."
echo "====================================================="
echo "=              Build libiconv                       ="
echo "====================================================="
echo "Configure libiconv starting..."
cd $BUILD_DIR/build-libiconv
$SRC_DIR/libiconv/configure --prefix=$PREFIX --enable-static --disable-shared
echo "Build libiconv starting..."
make -j1 && make install
echo "Build libiconv completed."

sleep 30
for d in build-zlib build-libiconv; do
    if [ -d $BUILD_DIR/$d ]; then
        rm -rf $BUILD_DIR/$d
        echo "remove $BUILD_DIR/$d"
    fi
done