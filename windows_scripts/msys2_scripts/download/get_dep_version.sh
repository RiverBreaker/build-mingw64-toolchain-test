# 读取JSON文件并提取对应GCC版本的依赖项
DEPS_JSON=$(cat dependencies.json)

# 使用jq解析
echo "Parsing dependencies for GCC $GCC_VERSION..."

# 提取所有依赖版本
ZLIB_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].zlib_version")
BINUTILS_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].binutils_version")
MINGW_W64_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].mingw_w64_version")
GDB_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].gdb_version")
READLINE_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].readline_version")
M4_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].m4_version")
LIBTOOL_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].libtool_version")
LIBICONV_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"$GCC_VERSION\"].libiconv_version")

# 验证是否找到版本
if [ "$GDB_VERSION" = "null" ]; then
  echo "Error: GDB version for GCC $GCC_VERSION not found in dependencies.json"
  exit 1
fi

# 设置环境变量（输出到GITHUB_ENV供后续步骤使用）
echo "ZLIB_VERSION=$ZLIB_VERSION" >> $GITHUB_ENV
echo "BINUTILS_VERSION=$BINUTILS_VERSION" >> $GITHUB_ENV
echo "MINGW_W64_VERSION=$MINGW_W64_VERSION" >> $GITHUB_ENV
echo "GDB_VERSION=$GDB_VERSION" >> $GITHUB_ENV
echo "READLINE_VERSION=$READLINE_VERSION" >> $GITHUB_ENV
echo "M4_VERSION=$M4_VERSION" >> $GITHUB_ENV
echo "LIBTOOL_VERSION=$LIBTOOL_VERSION" >> $GITHUB_ENV
echo "LIBICONV_VERSION=$LIBICONV_VERSION" >> $GITHUB_ENV

# 打印确认信息
echo "Successfully parsed dependencies:"
echo "ZLIB: $ZLIB_VERSION"
echo "BINUTILS: $BINUTILS_VERSION"
echo "MINGW_W64: $MINGW_W64_VERSION"
echo "GDB: $GDB_VERSION"
echo "READLINE: $READLINE_VERSION"
echo "M4: $M4_VERSION"
echo "LIBTOOL: $LIBTOOL_VERSION"
echo "LIBICONV: $LIBICONV_VERSION"
