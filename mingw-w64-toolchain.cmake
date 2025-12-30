# mingw-w64-toolchain.cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# 指定交叉编译器
set(CMAKE_C_COMPILER   x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER  x86_64-w64-mingw32-windres)
set(CMAKE_LD_COMPILER x86_64-w64-mingw32-ld)
set(CMAKE_AR x86_64-w64-mingw32-ar)
set(CMAKE_RANLIB x86_64-w64-mingw32-ranlib)

# 告诉 CMake where to find target headers/libs (sysroot)
# 如果有 MXE 或交叉 sysroot，可以设置 CMAKE_SYSROOT 或 include/link paths
# set(CMAKE_SYSROOT /path/to/mxe/usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH /home/runner/work/build-mingw64-toolchain-test/build-mingw64-toolchain-test/mingw-w64-native/x86_64-w64-mingw32)

# 搜索策略：先在交叉根找库和头
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
