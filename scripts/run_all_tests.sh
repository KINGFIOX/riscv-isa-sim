#!/usr/bin/env bash
# 运行所有测试，确保 Meson 构建正确
# 对应原: make check + ci-tests/test-spike
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
BUILD="$ROOT/build"

cd "$ROOT"

echo "========== 1. Meson 内置测试 (smoke + functional + regression) =========="
ninja -C build test
echo ""

echo "========== 2. libriscv 链接测试 (testlib.c 编译) =========="
g++ -std=c++17 -I"$ROOT" -I"$BUILD" -L"$BUILD" "$ROOT/ci-tests/testlib.c" -lriscv -o "$BUILD/test-libriscv"
echo "  OK: testlib.c 编译成功"
echo ""

echo "========== 3. CI 测试 (spike pk hello) =========="
if [ -f "$BUILD/run/hello" ] && [ -x "$BUILD/run/pk" ]; then
  "$BUILD/spike" --isa=rv64gc pk "$BUILD/run/hello" 2>&1 | grep -q "Hello, world!  Pi is approximately 3.141588." && echo "  OK: spike pk hello" || { echo "  FAIL: spike pk hello"; exit 1; }
  LD_LIBRARY_PATH="$BUILD" "$BUILD/test-libriscv" 2>&1 | grep -q "Hello, world!  Pi is approximately 3.141588." && echo "  OK: test-libriscv" || { echo "  FAIL: test-libriscv"; exit 1; }
else
  echo "  SKIP: 需要 pk 和 hello (从 spike-ci.tar 或 \$RISCV 获取)"
  echo "        可运行: cd build/run && wget <spike-ci.tar-url> && tar xf spike-ci.tar"
fi
echo ""

echo "========== 4. rv32im 回归测试 (tests/ebreak.py) =========="
# 面向 YSYX：CROSS_COMPILE=riscv32-unknown-linux-gnu- (flake.nix) + pk
_out=$("$ROOT/tests/run_ebreak_regression.sh" "$BUILD/spike" 2>&1)
ret=$?
echo "$_out"
if [ $ret -eq 0 ]; then
  if echo "$_out" | grep -q "SKIP:"; then
    echo "  SKIP: 需要 CROSS_COMPILE=riscv32-unknown-linux-gnu- 或 \$RISCV、pk"
  else
    echo "  OK: rv32im ebreak 回归测试"
  fi
else
  echo "  FAIL: rv32im ebreak 回归测试"
  exit 1
fi
echo ""

echo "========== 全部测试完成 =========="
