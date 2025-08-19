echo "====================================================="
echo "=              Build mingw64 toolchain              ="
echo "====================================================="
echo "====================================================="
echo "=              Build mingw64 binutils               ="
echo "====================================================="
ls -la $(pwd)
./build_scripts/binutils.sh || { echo "binutils build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 headers               ="
echo "====================================================="
./build_scripts/mingw64_headers.sh || { echo "headers build failed"; exit 1; }
echo "====================================================="
echo "=             Build mingw64 gcc tools               ="
echo "====================================================="
./build_scripts/gcc_tools.sh || { echo "gcc tools build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 gcc stage1             ="
echo "====================================================="
./build_scripts/gcc_stage1.sh || { echo "gcc stage1 build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 tools                  ="
echo "====================================================="
./build_scripts/mingw64_tools.sh || { echo "tools build failed"; exit 1; }
if [ $THREAD == "posix" ]; then
    echo "====================================================="
    echo "=              Build mingw64 posix                  ="
    echo "====================================================="
    ./build_scripts/mingw64_posix.sh || { echo "posix build failed"; exit 1; }
fi
echo "====================================================="
echo "=              Build mingw64 gcc stage2             ="
echo "====================================================="
./build_scripts/gcc_final.sh || { echo "gcc final build failed"; exit 1; }
echo "====================================================="
echo "=              Build mingw64 gdb                   ="
echo "====================================================="
./build_scripts/gdb.sh || { echo "gdb build failed"; exit 1; }