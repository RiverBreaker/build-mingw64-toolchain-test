# build-mingw64-toolchain-test

${PREFIX} : gcc binutils gdb mingw64-tools mingw-w64-libraries-libmangle make cmake

${PREFIX}/${TARGET} mingw-w64-libraries-winpthreads mingw-w64-headers mingw-w64-crt libiconv

${PREFIX}/opt zlib openssl sqlite python expat xz bzip2 gdbm readline ncurses libffi libgnurx


-I${TARGET_DIR}/include -L${TARGET_DIR}/lib

#define BZ_UNIX      1

/*--
  Win32, as seen by Jacob Navia's excellent
  port of (Chris Fraser & David Hanson)'s excellent
  lcc compiler.  Or with MS Visual C.
  This is selected automatically if compiled by a compiler which
  defines _WIN32, not including the Cygwin GCC.
--*/
#define BZ_LCCWIN32  0

+ #define BZ_MINGW32 0
#if defined(_WIN32) && !defined(__CYGWIN__) && defined(__MINGW32__)
#undef  BZ_UNIX
#define BZ_UNIX 0
#define BZ_MINGW32 1  /* 新增独立宏 */
#endif

#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__MINGW32__)
#undef  BZ_LCCWIN32
#define BZ_LCCWIN32 1
#undef  BZ_UNIX
#define BZ_UNIX 0
+ #undef BZ_MINGW32
+ #define BZ_MINGW32 0
#endif



/*---------------------------------------------*/
/*--
  Some stuff for all platforms.
--*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <math.h>
#include <errno.h>
#include <ctype.h>
#include "bzlib.h"

#define ERROR_IF_EOF(i)       { if ((i) == EOF)  ioError(); }
#define ERROR_IF_NOT_ZERO(i)  { if ((i) != 0)    ioError(); }
#define ERROR_IF_MINUS_ONE(i) { if ((i) == (-1)) ioError(); }


/*---------------------------------------------*/
/*--
   Platform-specific stuff.
--*/

#if BZ_UNIX
#   include <fcntl.h>
#   include <sys/types.h>
#   include <utime.h>
#   include <unistd.h>
#   include <sys/stat.h>
#   include <sys/times.h>

#   define PATH_SEP    '/'
#   define MY_LSTAT    lstat
#   define MY_STAT     stat
#   define MY_S_ISREG  S_ISREG
#   define MY_S_ISDIR  S_ISDIR

#   define APPEND_FILESPEC(root, name) \
      root=snocString((root), (name))

#   define APPEND_FLAG(root, name) \
      root=snocString((root), (name))

#   define SET_BINARY_MODE(fd) /**/

#   ifdef __GNUC__
#      define NORETURN __attribute__ ((noreturn))
#   else
#      define NORETURN /**/
#   endif

#   ifdef __DJGPP__
#     include <io.h>
#     include <fcntl.h>
#     undef MY_LSTAT
#     undef MY_STAT
#     define MY_LSTAT stat
#     define MY_STAT stat
#     undef SET_BINARY_MODE
#     define SET_BINARY_MODE(fd)                        \
        do {                                            \
           int retVal = setmode ( fileno ( fd ),        \
                                  O_BINARY );           \
           ERROR_IF_MINUS_ONE ( retVal );               \
        } while ( 0 )
#   endif

#   ifdef __CYGWIN__
#     include <io.h>
#     include <fcntl.h>
#     undef SET_BINARY_MODE
#     define SET_BINARY_MODE(fd)                        \
        do {                                            \
           int retVal = setmode ( fileno ( fd ),        \
                                  O_BINARY );           \
           ERROR_IF_MINUS_ONE ( retVal );               \
        } while ( 0 )
#   endif
#endif /* BZ_UNIX */



#if BZ_LCCWIN32
#   include <io.h>
#   include <fcntl.h>
#   include <sys/stat.h>

#   define NORETURN       /**/
#   define PATH_SEP       '\\'
#   define MY_LSTAT       _stati64
#   define MY_STAT        _stati64
#   define MY_S_ISREG(x)  ((x) & _S_IFREG)
#   define MY_S_ISDIR(x)  ((x) & _S_IFDIR)

#   define APPEND_FLAG(root, name) \
      root=snocString((root), (name))

#   define APPEND_FILESPEC(root, name)                \
      root = snocString ((root), (name))

#   define SET_BINARY_MODE(fd)                        \
      do {                                            \
         int retVal = setmode ( fileno ( fd ),        \
                                O_BINARY );           \
         ERROR_IF_MINUS_ONE ( retVal );               \
      } while ( 0 )

#endif /* BZ_LCCWIN32 */

+ #if BZ_MINGW32
+ #   define PATH_SEP       '/'
+ #   include <io.h>
+ #   include <fcntl.h>
+ #   include <sys/stat.h>
+
+ #   define NORETURN       /**/
+ #   define MY_LSTAT       _stati64
+ #   define MY_STAT        _stati64
+ #   define MY_S_ISREG(x)  ((x) & _S_IFREG)
+ #   define MY_S_ISDIR(x)  ((x) & _S_IFDIR)
+
+ #   define APPEND_FLAG(root, name) \
+     root=snocString((root), (name))
+
+ #   define APPEND_FILESPEC(root, name)                \
+     root = snocString ((root), (name))
+
+ #   define SET_BINARY_MODE(fd)                        \
+      do {                                            \
+         int retVal = setmode ( fileno ( fd ),        \
+                                O_BINARY );           \
+         ERROR_IF_MINUS_ONE ( retVal );               \
+      } while ( 0 )
+
+ #endif /* BZ_MINGW32 */
