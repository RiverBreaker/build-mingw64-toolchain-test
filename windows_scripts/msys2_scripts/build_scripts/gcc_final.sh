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

case "$ARCH" in
  x86_64) TARGET="x86_64-w64-mingw32"; 
  ARCH_CFG="--with-arch=x86-64 --with-tune=generic";
  CFLAGS_FOR_TARGET="-O2 -march=x86-64" ;;
  i686)   TARGET="i686-w64-mingw32";
  ARCH_CFG="--with-arch=i686 --with-tune=generic";
  CFLAGS_FOR_TARGET="-O2 -march=i686"   ;;
  *) echo "Unsupported ARCH: $ARCH"; exit 1 ;;
esac

case "$THREAD" in
  posix) THREAD_CFG="--enable-threads=posix" ;;
  win32) THREAD_CFG="--enable-threads=win32" ;;
  *) echo "Unsupported THREAD: $THREAD"; exit 1 ;;
esac

case "$EXCEPTION" in
  sjlj)  EXC_CFG="--enable-sjlj-exceptions" ;;
  dwarf) EXC_CFG="--enable-dw2-exceptions" ;;
  seh)   EXC_CFG="--enable-seh-exceptions" ;;
esac

if [ -d $BUILD_DIR/build-gcc2 ]; then
    rm -rf $BUILD_DIR/build-gcc2
    echo "remove $BUILD_DIR/build-gcc2"
fi
mkdir -p $BUILD_DIR/build-gcc2
echo "mkdir $BUILD_DIR/build-gcc2"

gcc_src=$(realpath --relative-to="${BUILD_DIR}/build-gcc2" "${SRC_DIR}/gcc")

cd $BUILD_DIR/build-gcc2
echo "Configure win mingw gcc/g++ starting..."
${gcc_src}/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --target=$TARGET \
    --with-sysroot=$SYSROOT \
    --with-native-system-header-dir=/include \
    --with-local-prefix=$PREFIX/local \
    --disable-nls \
    --disable-lto \
    --disable-multilib \
    --disable-win32-registry \
    --disable-libstdcxx-pch \
    --disable-symvers \
    --enable-shared \
    --enable-static \
    --enable-languages=c,c++,fortran \
    --enable-libstdcxx-debug \
    --enable-version-specific-runtime-libs \
    --enable-decimal-float=yes \
    $THREAD_CFG \
    $EXC_CFG \
    $ARCH_CFG \
    --enable-tls \
    --enable-fully-dynamic-string \
    --with-gnu-ld \
    --with-gnu-as \
    --without-newlib \
    CPPFLAGS_FOR_TARGET="-I$PREFIX/$TARGET/include -I$PREFIX/include" \
    LDFLAGS_FOR_TARGET="-L$PREFIX/$TARGET/lib -L$PREFIX/lib"

echo "Configure gcc stage 2 done"
make -j1 V=1 all-gcc || { echo "all-gcc failed"; exit 1; }
make install-gcc || { echo "install-gcc failed"; exit 1; }

# 构建 target 的 libgcc 时把 *_FOR_TARGET 传给 make
make -j1 V=1 all-target-libgcc CPPFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET" \
                               CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
                               LDFLAGS_FOR_TARGET="$LDFLAGS_FOR_TARGET" || { echo "all-target-libgcc failed"; exit 1; }
make install-target-libgcc CPPFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET" \
                           CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
                           LDFLAGS_FOR_TARGET="$LDFLAGS_FOR_TARGET" || { echo "install-target-libgcc failed"; exit 1; }

# 若需构建 libstdc++:
make -j1 V=1 all-target-libstdc++-v3 CPPFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET" \
                                    CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
                                    LDFLAGS_FOR_TARGET="$LDFLAGS_FOR_TARGET" || { echo "all-target-libg++-v3 failed"; exit 1; }
make install-target-libstdc++-v3 CPPFLAGS_FOR_TARGET="$CPPFLAGS_FOR_TARGET" \
                                    CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
                                    LDFLAGS_FOR_TARGET="$LDFLAGS_FOR_TARGET" || { echo "install-target-libg++-v3 failed"; exit 1; }
echo "Build gcc stage 2 done"
if [ -x "$PREFIX/bin/$TARGET-gcc" ] && [ -x "$PREFIX/bin/$TARGET-g++" ]; then
    echo "GCC final installation verified successfully."
else
    echo "GCC final installation verification failed." >&2
fi

sleep 30
if [ -d $BUILD_DIR/build-gcc2 ]; then
    rm -rf $BUILD_DIR/build-gcc2
    echo "remove $BUILD_DIR/build-gcc2"
fi
