FUNCTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FUNCTION_DIR/../function/win_2_posix_abs.sh"
WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
normalize_var WORKDIR
SRC_DIR="${WORKDIR}/src"
echo "Using WORKDIR: $WORKDIR"
echo "Preparing source dir: $SRC_DIR"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../patch"

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
BINUTILS_NOP_VERSION=${BINUTILS_VERSION//./_}
echo "Cloning Binutils repository..."
if [ ! -d binutils ]; then
  git clone https://github.com/bminor/binutils-gdb.git binutils
fi
cd binutils
git fetch --tags --prune
git checkout tags/binutils-${BINUTILS_NOP_VERSION} -b binutils-${BINUTILS_NOP_VERSION} || \
git checkout binutils-${BINUTILS_NOP_VERSION}
if [ -f gas/doc/.dirstamp ]; then
    echo "rm gas/doc/.dirstamp"
    rm gas/doc/.dirstamp
fi
if git apply --check "$PATCH_DIR/fix-binutils-dlltool-alpha.patch"; then
  echo "fallback patch check OK — applying stripped patch"
  git apply "$PATCH_DIR/fix-binutils-dlltool-alpha.patch"
else
  echo "Both primary and fallback patch checks failed. Show first 80 lines of patch for diagnosis:"
  nl -ba -w3 -s': ' "$PATCH_DIR/fix-binutils-dlltool-alpha.patch" | sed -n '1,80p'
  echo "Also trying to show git apply verbose output:"
  git apply --check --verbose "$PATCH_DIR/fix-binutils-dlltool-alpha.patch" 2>&1
  exit 1
fi
cd ..

# Clone the GCC repository
echo "Cloning GCC repository..."
if [ ! -d gcc ]; then
  git clone https://github.com/gcc-mirror/gcc.git gcc
fi
cd gcc
git fetch --tags --prune
git checkout tags/releases/gcc-${GCC_VERSION} -b releases/gcc-${GCC_VERSION} || \
git checkout releases/gcc-${GCC_VERSION}

# Download prerequisites for GCC (this requires network/wget/curl)
if [ -x contrib/download_prerequisites ]; then
  echo "Running contrib/download_prerequisites..."
  ./contrib/download_prerequisites
else
  echo "Warning: contrib/download_prerequisites not found or not executable yet; ensure you run this inside gcc source dir."
fi
cd ..

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
  wget -c https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.gz
  tar -xzf gdb-${GDB_VERSION}.tar.gz
  mv gdb-${GDB_VERSION} gdb
  rm -f gdb-${GDB_VERSION}.tar.gz
fi

# Download Libiconv
echo "Downloading Libiconv source code..."
if [ ! -d libiconv ]; then
  wget -c https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz
  tar -xzf libiconv-1.18.tar.gz
  mv libiconv-1.18 libiconv
  rm -f libiconv-1.18.tar.gz
fi

# Download M4
echo "Downloading M4 source code..."
if [ ! -d m4 ]; then
  wget -c https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.gz
  tar -xzf m4-1.4.20.tar.gz
  mv m4-1.4.20 m4
  rm -f m4-1.4.20.tar.gz
fi

# Download Libtool
echo "Downloading Libtool source code..."
if [ ! -d libtool ]; then
  wget -c https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.gz
  tar -xzf libtool-2.5.4.tar.gz
  mv libtool-2.5.4 libtool
  rm -f libtool-2.5.4.tar.gz
fi

echo "All downloads completed."
