# 读取JSON文件并提取对应GCC版本的依赖项
DEPS_JSON=$(cat dependencies.json)

# 使用jq解析（推荐方法，更可靠）
echo "Parsing dependencies for GCC ${{ env.GCC_VERSION }}..."

# 提取所有依赖版本
ZLIB_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"${{ env.GCC_VERSION }}\"].zlib_version")
BINUTILS_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"${{ env.GCC_VERSION }}\"].binutils_version")
MINGW_W64_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"${{ env.GCC_VERSION }}\"].mingw_w64_version")
GDB_VERSION=$(echo "$DEPS_JSON" | jq -r ".gcc_versions[\"${{ env.GCC_VERSION }}\"].gdb_version")

# 验证是否找到版本
if [ "$GDB_VERSION" = "null" ]; then
  echo "Error: GDB version ${{ env.GDB_VERSION }} not found in dependencies.json"
  exit 1
fi

# 设置环境变量（输出到GITHUB_ENV供后续步骤使用）
echo "ZLIB_VERSION=$ZLIB_VERSION" >> $GITHUB_ENV
echo "BINUTILS_VERSION=$BINUTILS_VERSION" >> $GITHUB_ENV
echo "MINGW_W64_VERSION=$MINGW_W64_VERSION" >> $GITHUB_ENV
echo "GDB_VERSION=$GDB_VERSION" >> $GITHUB_ENV

# 打印确认信息
echo "Successfully parsed dependencies:"
echo "ZLIB: $ZLIB_VERSION"
echo "BINUTILS: $BINUTILS_VERSION"
echo "MINGW_W64: $MINGW_W64_VERSION"
echo "GDB: $GDB_VERSION"