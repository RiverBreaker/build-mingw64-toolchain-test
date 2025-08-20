echo "====================================================="
echo "=              Build mingw64 toolchain              ="
echo "====================================================="
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
echo "ARCH: $ARCH"
echo "THREAD: $THREAD"
echo "EXCEPTION: $EXCEPTION"
echo "CRT: $CRT"
echo "MSYSTEM: $MSYSTEM"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
echo "====================================================="
echo "=           Build host tools (m4, libtool)          ="
echo "====================================================="
echo "Skipping host tools build."
# $SCRIPT_DIR/build_scripts/host_tools.sh || { echo "host tools build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 binutils               ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/binutils.sh || { echo "binutils build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 headers               ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/mingw64_headers.sh || { echo "headers build failed"; exit 1; }
echo "====================================================="
echo "=             Build mingw64 gcc tools               ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/gcc_tools.sh || { echo "gcc tools build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 gcc stage1             ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/gcc_stage1.sh || { echo "gcc stage1 build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 target tools           ="
echo "====================================================="
echo "Skipping target tools build."
# $SCRIPT_DIR/build_scripts/target_tools.sh || { echo "target tools build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 tools                  ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/mingw64_tools.sh || { echo "tools build failed"; exit 1; }
if [ $THREAD == "posix" ]; then
    echo "====================================================="
    echo "=              Build mingw64 posix                  ="
    echo "====================================================="
    $SCRIPT_DIR/build_scripts/mingw64_posix.sh || { echo "posix build failed"; exit 1; }
fi
echo "====================================================="
echo "=              Build mingw64 gcc stage2             ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/gcc_final.sh || { echo "gcc final build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 readline               ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/readline.sh || { echo "readline build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 gdb                   ="
echo "====================================================="
$SCRIPT_DIR/build_scripts/gdb.sh || { echo "gdb build failed"; exit 1; }