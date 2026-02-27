#!/usr/bin/env bash
# rv32im 回归测试 tests/ebreak.py（对应原 Makefile 的 check-bin）
# 面向 YSYX：CROSS_COMPILE=riscv32-unknown-linux-gnu- 或 $RISCV，spike 作为 rv32im golden model
# 用法: run_ebreak_regression.sh <spike可执行文件路径>
set -e
SPIKE="$1"
ISA="${RISCV_ISA:-rv32im}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -z "$SPIKE" ] || [ ! -x "$SPIKE" ]; then
  echo "Usage: $0 <path-to-spike>" >&2
  exit 1
fi

# 检测编译器：优先 CROSS_COMPILE (YSYX flake)、RISCV_CC、$RISCV
CC=""
[ -n "$RISCV_CC" ] && CC="$RISCV_CC"
[ -z "$CC" ] && [ -n "$CROSS_COMPILE" ] && CC="${CROSS_COMPILE}gcc"
[ -z "$CC" ] && [ -n "$RISCV" ] && [ -x "$RISCV/bin/riscv32-unknown-elf-gcc" ] && CC="$RISCV/bin/riscv32-unknown-elf-gcc"
[ -z "$CC" ] && [ -n "$RISCV" ] && [ -x "$RISCV/bin/riscv32-unknown-linux-gnu-gcc" ] && CC="$RISCV/bin/riscv32-unknown-linux-gnu-gcc"
[ -z "$CC" ] && command -v riscv32-unknown-linux-gnu-gcc >/dev/null 2>&1 && CC="riscv32-unknown-linux-gnu-gcc"
[ -z "$CC" ] && [ -n "$RISCV" ] && [ -x "$RISCV/bin/riscv64-unknown-elf-gcc" ] && CC="$RISCV/bin/riscv64-unknown-elf-gcc"

if [ -z "$CC" ] || ! command -v "$CC" >/dev/null 2>&1; then
  echo "SKIP: no RISC-V gcc (need CROSS_COMPILE=riscv32-unknown-linux-gnu- or \$RISCV)"
  exit 0
fi

_has_pk=false
command -v pk >/dev/null 2>&1 && _has_pk=true
[ -n "$RISCV" ] && [ -x "$RISCV/riscv32-unknown-elf/bin/pk" ] && _has_pk=true
[ -n "$RISCV" ] && [ -x "$RISCV/riscv32-unknown-linux-gnu/bin/pk" ] && _has_pk=true
[ -n "$RISCV" ] && [ -x "$RISCV/riscv64-unknown-elf/bin/pk" ] && _has_pk=true
if [ -n "$YSYX_HOME" ] && [ -x "$YSYX_HOME/riscv-pk/build/pk" ]; then
  _has_pk=true
  export PATH="$YSYX_HOME/riscv-pk/build:$PATH"
fi
if [ "$_has_pk" = false ]; then
  echo "SKIP: pk not found (need riscv32 pk in PATH or \$RISCV or \$YSYX_HOME/riscv-pk)"
  exit 0
fi

# testlib.find_file("spike") 在 cwd 或 tests/ 下查找，故需 spike 在此目录
ln -sf "$(realpath "$SPIKE")" spike 2>/dev/null || cp "$SPIKE" spike
chmod +x spike

export RISCV_CC="$CC"
export RISCV_ISA="$ISA"
export SPIKE_ISA="$ISA"
python3 ebreak.py > ebreak.out 2>&1
ret=$?
cat ebreak.out
if [ "$ret" -ne 0 ]; then
  echo "REGRESSION: ebreak.py exited with $ret"
  exit 1
fi
if grep -q FAILED ebreak.out; then
  echo "REGRESSION: ebreak.py output contains FAILED"
  exit 1
fi
