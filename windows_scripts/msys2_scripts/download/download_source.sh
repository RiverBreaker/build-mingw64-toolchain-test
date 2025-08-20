FUNCTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FUNCTION_DIR/../function/win_2_posix_abs.sh"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
normalize_var WORKDIR
SRC_DIR="${WORKDIR}/src"
echo "Using WORKDIR: $WORKDIR"
echo "Preparing source dir: $SRC_DIR"
PATCH_DIR="${WORKDIR}/windows_scripts/patch"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

git config --global core.autocrlf false || true
echo "git core.autocrlf=$(git config --global core.autocrlf || echo 'unset')"

# Clone the Mingw-w64 repository
echo "Cloning Mingw-w64 repository..."
if [ ! -d mingw-w64 ]; then
  git clone https://github.com/mingw-w64/mingw-w64.git mingw-w64
fi
cd mingw-w64
git fetch --tags --prune
git checkout tags/v${MINGW_W64_VERSION} -b v${MINGW_W64_VERSION} || git checkout v${MINGW_W64_VERSION}
cd ..

# Clone the Binutils repository
echo "Downloading Binutils repository..."
if [ ! -d binutils ]; then
  wget -c https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz && \
  tar -xzf binutils-${BINUTILS_VERSION}.tar.gz && \
  mv binutils-${BINUTILS_VERSION} binutils && \
  rm -f binutils-${BINUTILS_VERSION}.tar.gz
  if [ -f binutils/gas/doc/.dirstamp ]; then
    echo "rm binutils/gas/doc/.dirstamp"
    rm -f binutils/gas/doc/.dirstamp
  fi
fi

# Clone the GCC repository
echo "Cloning GCC repository..."
if [ ! -d gcc ]; then
  wget -c https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz && \
  tar -xzf gcc-${GCC_VERSION}.tar.gz && \
  mv gcc-${GCC_VERSION} gcc && \
  rm -f gcc-${GCC_VERSION}.tar.gz
  cd gcc
  if [ -x contrib/download_prerequisites ]; then
    echo "Running contrib/download_prerequisites..."
    ./contrib/download_prerequisites
  else
    echo "Warning: contrib/download_prerequisites not found or not executable yet; ensure you run this inside gcc source dir."
  fi
  cd ..
fi

# Download readline
echo "Downloading readline source code..."
if [ ! -d readline ]; then
  wget -c https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz && \
  tar -xzf readline-${READLINE_VERSION}.tar.gz && \
  mv readline-${READLINE_VERSION} readline && \
  rm -f readline-${READLINE_VERSION}.tar.gz
fi

# Download MCF Threading Library
# if [ $GCC_VERSION <= 13.0.0 ]; then
#   if [ $THREAD == "mcf" ]; then
#       echo "Downloading MCF Threading Library source code..."
#       if [ ! -d mcf ]; then
#           git clone https://github.com/MCFThreadingLibrary/MCFThreadingLibrary.git mcf
#       fi
#   fi
# fi

# Download GDB
echo "Downloading GDB source code..."
if [ ! -d gdb ]; then
  wget -c https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz && \
  tar -xzf gdb-${GDB_VERSION}.tar.gz && \
  mv gdb-${GDB_VERSION} gdb && \
  rm -f gdb-${GDB_VERSION}.tar.gz
fi

# Download Libiconv
echo "Downloading Libiconv source code..."
if [ ! -d libiconv ]; then
  wget -c https://ftp.gnu.org/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz && \
  tar -xzf libiconv-${LIBICONV_VERSION}.tar.gz && \
  mv libiconv-${LIBICONV_VERSION} libiconv && \
  rm -f libiconv-${LIBICONV_VERSION}.tar.gz
fi

# Download M4
echo "Downloading M4 source code..."
if [ ! -d m4 ]; then
  wget -c https://ftp.gnu.org/gnu/m4/m4-${M4_VERSION}.tar.gz && \
  tar -xzf m4-${M4_VERSION}.tar.gz && \
  mv m4-${M4_VERSION} m4 && \
  rm -f m4-${M4_VERSION}.tar.gz
fi

# Download Libtool
echo "Downloading Libtool source code..."
if [ ! -d libtool ]; then
  wget -c https://ftp.gnu.org/gnu/libtool/libtool-${LIBTOOL_VERSION}.tar.gz && \
  tar -xzf libtool-${LIBTOOL_VERSION}.tar.gz && \
  mv libtool-${LIBTOOL_VERSION} libtool && \
  rm -f libtool-${LIBTOOL_VERSION}.tar.gz
fi

echo "All downloads completed."
