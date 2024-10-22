#!/bin/bash
# Top-level script to perform all steps
#set -e

# Define directories and paths
LLVM_SRC_DIR="/home/linus/Compilers/llvm-project"

build_bootstrap="/home/linus/Compilers/riscv-mlir/build-bootstrap-tblgen"
build_x86="/home/linus/Compilers/riscv-mlir/build-x86"
build_riscv="/home/linus/Compilers/riscv-mlir/build-riscv"
install_bootstrap="/home/linus/Compilers/riscv-mlir/install-bootstrap-tblgen"
install_x86="/home/linus/Compilers/riscv-mlir/install-x86"
install_riscv="/home/linus/Compilers/riscv-mlir/install-riscv"

mkdir -p "$build_bootstrap"
mkdir -p "$build_x86"
mkdir -p "$build_riscv"
mkdir -p "$install_bootstrap"
mkdir -p "$install_x86"
mkdir -p "$install_riscv"

RISCV_PATH="/home/linus/Compilers/riscv32-glibc-llvm/riscv"
RISCV_C_COMPILER="${RISCV_PATH}/bin/riscv32-unknown-linux-gnu-gcc"
RISCV_CXX_COMPILER="${RISCV_PATH}/bin/riscv32-unknown-linux-gnu-g++"

BUILD_TABLE_GEN=0
BUILD_MLIR=0
BUILD_COMPILE_FOR_RV32=1

if [ $BUILD_TABLE_GEN -eq 1 ];
then
echo "Building table gen"
# Step 1: Bootstrap mlir-tblgen binaries
cmake -GNinja \
  "-H$LLVM_SRC_DIR/llvm" \
  "-B$build_bootstrap" \
  -DCMAKE_C_COMPILER=clang-18 \
  -DCMAKE_CXX_COMPILER=clang++-18 \
  -DCMAKE_INSTALL_PREFIX=$install_bootstrap \
  -DLLVM_INSTALL_UTIL=ON \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_ENABLE_PROJECTS="clang;llvm;mlir" \
  -DLLVM_PARALLEL_LINK_JOBS=2 \
  -DLLVM_TARGET_ARCH="host" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_bootstrap" --target clang-tblgen llvm-tblgen mlir-tblgen -j12 --target install
fi
# Step 2: Compile LLVM, Clang, and MLIR for x86 with RISC-V
if [ $BUILD_MLIR -eq 1 ]; 
then
echo "building mlir " 
cmake -GNinja \
  "-H$LLVM_SRC_DIR/llvm" \
  "-B$build_x86" \
  -DCMAKE_INSTALL_PREFIX=$install_x86 \
  -DLLVM_ENABLE_PROJECTS="clang;llvm;mlir" \
  -DLLVM_TARGET_ARCH="host" \
  -DLLVM_TARGETS_TO_BUILD="host;RISCV" \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "$build_x86" --target clang opt mlir-opt mlir-translate mlir-cpu-runner FileCheck -j2 --target install
fi
# Step 3: Cross-compile MLIR runner libraries for RISC-V
if [ $BUILD_COMPILE_FOR_RV32 -eq 1 ]
then
echo "Building Compile for rv32"
cmake -GNinja \
  "-H$LLVM_SRC_DIR/llvm" \
  "-B$build_riscv" \
  -DDEFAULT_SYSROOT="${RISCV_PATH}/sysroot" \
  -DCMAKE_INSTALL_PREFIX=$install_riscv \
  -DMLIR_TABLEGEN=$build_bootstrap/bin/mlir-tblgen \
  -DLLVM_TABLEGEN=$build_bootstrap/bin/llvm-tblgen \
  -DCLANG_TABLEGEN=$build_bootstrap/bin/clang-tblgen \
  -DMLIR_LINALG_ODS_YAML_GEN=$build_bootstrap/bin/mlir-linalg-ods-yaml-gen \
  -DLLVM_ENABLE_PROJECTS="mlir" \
  -DCMAKE_C_COMPILER="$RISCV_C_COMPILER" \
  -DCMAKE_CXX_COMPILER="$RISCV_CXX_COMPILER" \
  -DCMAKE_CROSSCOMPILING=True \
  -DLLVM_TARGETS_TO_BUILD="RISCV" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="riscv32-unknown-linux-gnu" \
  -DGCC_INSTALL_PREFIX="${RISCV_PATH}" \
  -DMLIR_ENABLE_BINDINGS_PYTHON=OFF\
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_INSTALL_UTILS=OFF  \
  -DLLVM_ENABLE_LLD=OFF \
  -DLLVM_BUILD_TOOLS=OFF  \
  -DLLVM_INCLUDE_TOOLS=ON \
  -DLLVM_INCLUDE_TESTS=OFF  \
  -DMLIR_INCLUDE_TESTS=OFF   \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_BUILD_EXAMPLES=OFF
cmake --build "$build_riscv" --target MLIRCRunnerUtils -j4 --target install 
fi

#MLIRExecutionEngineUtils
#libMLIRExecutionEngineUtils.a 
# Step 4: Compile and link application
#app_mlir="/path/to/app.mlir"
#/path/to/build-x86/bin/mlir-opt -convert-linalg-to-loops -convert-scf-to-std -convert-linalg-to-llvm -lower-affine -convert-scf-to-std --convert-memref-to-llvm -convert-std-to-llvm -reconcile-unrealized-casts -o /path/to/app-llvm.mlir $app_mlir
#/path/to/build-x86/bin/mlir-translate -mlir-to-llvmir -o /path/to/app.ll /path/to/app-llvm.mlir
#/path/to/build-x86/bin/clang --target=riscv32-unknown-elf -march=rv32gc -c -o /path/to/app.o /path/to/app.ll
#/path/to/build-x86/bin/clang -o /path/to/app /path/to/app.o --target=riscv32-unknown-elf -Wl,-rpath=/path/to/build-riscv/lib -L/path/to/build-riscv/lib -lmlir_runner_utils

# Step 5: Run the application
#qemu-riscv32 /path/to/app
