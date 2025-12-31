# build-mingw64-toolchain-test

${PREFIX} : gcc binutils gdb mingw64-tools mingw-w64-libraries-libmangle make cmake

${PREFIX}/${TARGET} mingw-w64-libraries-winpthreads mingw-w64-headers mingw-w64-crt libiconv

${PREFIX}/opt zlib openssl sqlite python expat xz bzip2 gdbm readline ncurses libffi libgnurx