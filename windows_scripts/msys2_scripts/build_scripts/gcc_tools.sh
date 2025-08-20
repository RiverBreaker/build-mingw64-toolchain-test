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
export PATH="$PREFIX/bin:$PATH"

for d in build-gmp build-mpfr build-mpc build-isl; do
    if [ ! -d $BUILD_DIR/$d ]; then
        mkdir -p $BUILD_DIR/$d
        echo "mkdir $BUILD_DIR/$d"
    fi
done

src=$(realpath --relative-to="${BUILD_DIR}/build-gmp" "${SRC_DIR}")
for d in gmp mpfr mpc isl; do
    if [ -d "${SRC_DIR}/gcc/$d" ]; then
        mv ${src}/gcc/$d ${SRC_DIR}/
        echo "Move ${src}/gcc/$d to ${SRC_DIR}/"
    fi
done

# Build dependencies
# #
# Build GMP
cd $BUILD_DIR/build-gmp
echo "Configure win mingw gmp starting..."
${SRC_DIR}/gmp/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --enable-shared \
    --disable-static \
    --enable-cxx
echo "Configure GMP completed."
make -j1 && make install
echo "Build GMP completed."
if [ -f "$PREFIX/lib/libgmp.a" ]; then
    echo "GMP installation verified successfully."
else
    echo "GMP installation verification failed." >&2
fi

# Build MPFR
cd $BUILD_DIR/build-mpfr
echo "Configure win mingw mpfr starting..."
${SRC_DIR}/mpfr/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --enable-shared \
    --disable-static \
    --with-gmp=$PREFIX
echo "Configure MPFR completed."
make -j1 && make install
echo "Build MPFR completed."
if [ -f "$PREFIX/lib/libmpfr.a" ]; then
    echo "MPFR installation verified successfully."
else
    echo "MPFR installation verification failed." >&2
fi

# Build MPC
cd $BUILD_DIR/build-mpc
echo "Configure win mingw mpc starting..."
${SRC_DIR}/mpc/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --enable-shared \
    --disable-static \
    --with-mpfr=$PREFIX \
    --with-gmp=$PREFIX
echo "Configure MPC completed."
make -j1 && make install
echo "Build MPC completed."
if [ -f "$PREFIX/lib/libmpc.a" ]; then
    echo "MPC installation verified successfully."
else
    echo "MPC installation verification failed." >&2
fi

# Build ISL
cd $BUILD_DIR/build-isl
echo "Configure win mingw isl starting..."
${SRC_DIR}/isl/configure \
    --prefix=$PREFIX \
    --build=$BUILD \
    --host=$HOST \
    --enable-shared \
    --disable-static \
    --with-gmp-prefix=$PREFIX
echo "Configure ISL completed."
make -j1 && make install 
echo "Build ISL completed."
if [ -f "$PREFIX/lib/libisl.a" ]; then
    echo "ISL installation verified successfully."
else
    echo "ISL installation verification failed." >&2
fi

for d in build-gmp build-mpfr build-mpc build-isl; do
    if [ -d $BUILD_DIR/$d ]; then
        rm -rf $BUILD_DIR/$d
        echo "remove $BUILD_DIR/$d"
    fi
done