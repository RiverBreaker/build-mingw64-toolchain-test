if [ "$ARCH" = "x86_64" ]; then
    if [ "$CRT" = "ucrt" ]; then
        export MSYSTEM=UCRT64
        pacman -S --needed --noconfirm \
            mingw-w64-ucrt-x86_64-toolchain \
            mingw-w64-ucrt-x86_64-zlib \
            mingw-w64-ucrt-x86_64-gettext
        export PATH="/ucrt64/bin:$PATH"
    else
        export MSYSTEM=MINGW64
        pacman -S --needed --noconfirm \
            mingw-w64-x86_64-toolchain \
            mingw-w64-x86_64-zlib \
            mingw-w64-x86_64-gettext
        export PATH="/mingw64/bin:$PATH"
    fi    
else
    if [ "$CRT" = "msvcrt" ]; then
        export MSYSTEM=MINGW32
        pacman -S --needed --noconfirm \
            mingw-w64-i686-toolchain \
            mingw-w64-i686-zlib \
            mingw-w64-i686-gettext
        export PATH="/mingw32/bin:$PATH"
    fi
fi