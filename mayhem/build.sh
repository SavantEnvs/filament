#!/usr/bin/env bash
#
# mayhem/build.sh — builds filament's parser/decoder libraries with sanitizers + coverage, links
# each fuzz harness (libFuzzer + standalone), and builds the upstream gtest suites with normal flags.
# Runs inside the commit image as `mayhem` in /mayhem; re-runnable and offline.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${SRC:=/mayhem}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
FUZZ_DIR="$SRC/out-fuzz"
TEST_DIR="$SRC/out-test"

# Configuration shared by both builds. Only the host libraries and tools needed for
# parsing/decoding are built: no engine, backends, samples or windowing.
# CMake wipes a build dir whose cached compiler path differs from the one requested, and the
# reconfigure then loses -DUSE_STATIC_LIBCXX=OFF. The path seen via PATH changes between the
# ccache-prefilled image build and a plain re-run, so reuse whatever the existing cache recorded.
compiler_for() {  # <cache-dir> <C|CXX> <fallback command>
  local c=""
  [ -f "$1/CMakeCache.txt" ] && c="$(sed -n "s/^CMAKE_$2_COMPILER:[A-Z]*=//p" "$1/CMakeCache.txt")"
  if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; else command -v "$3"; fi
}
cmake_common() {  # <cache-dir>
  CMAKE_COMMON=(
  -G Ninja -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$(compiler_for "$1" C "$CC")" -DCMAKE_CXX_COMPILER="$(compiler_for "$1" CXX "$CXX")"
  -DUSE_STATIC_LIBCXX=OFF
  -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_SKIP_SDL2=ON
  -DFILAMENT_SUPPORTS_VULKAN=OFF -DFILAMENT_SUPPORTS_XCB=OFF -DFILAMENT_SUPPORTS_XLIB=OFF
  )
}

# 1) The project itself, sanitized and coverage-instrumented (fuzz build).
FUZZ_FLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS"
cmake_common "$FUZZ_DIR"
cmake -S "$SRC" -B "$FUZZ_DIR" "${CMAKE_COMMON[@]}" -DFILAMENT_BUILD_TESTING=OFF \
      -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS"
cmake --build "$FUZZ_DIR" -j"$MAYHEM_JOBS" --target \
      utils filabridge filaflat uberz image png z tinyexr smol-v filamat matp zstd shaders

# 2) Harnesses, each twice: libFuzzer and standalone reproducer.
B="$FUZZ_DIR"
INCS=(
  -I"$SRC/libs/utils/include" -I"$SRC/libs/math/include" -I"$SRC/libs/filabridge/include"
  -I"$SRC/libs/filaflat/include" -I"$SRC/libs/filamat/include" -I"$SRC/libs/filament-matp/include"
  -I"$SRC/libs/image/include" -I"$SRC/libs/imageio/include" -I"$SRC/libs/uberz/include"
  -I"$SRC/filament/include" -I"$SRC/filament/src" -I"$SRC/filament/backend/include"
  -I"$SRC/third_party/robin-map/include" -I"$SRC/third_party/zstd/lib"
  -I"$SRC/third_party/smol-v/source" -I"$SRC/third_party/libpng" -I"$B/third_party/libpng/tnt"
  -I"$SRC/third_party/libpng/tnt" -I"$SRC/third_party/tinyexr"
  -I"$SRC/third_party/glslang" -I"$SRC/third_party/spirv-tools/include"
  -I"$SRC/third_party/spirv-headers/include" -I"$B/include" -I"$B/shaders"
)
DEFS=(-DNDEBUG -DFILAMENT_SUPPORTS_OPENGL -DFILAMENT_SUPPORTS_MOTION_VECTORS)
CXXFLAGS=(-std=c++20 -O1 -fno-rtti "${DEFS[@]}")
HFLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS"

LIBS=(
  "$B/libs/filamat/libfilamat.a" "$B/shaders/libshaders.a" "$B/libs/filament-matp/libmatp.a" "$B/libs/filaflat/libfilaflat.a"
  "$B/libs/uberz/libuberzlib.a" "$B/libs/image/libimage.a" "$B/libs/filabridge/libfilabridge.a"
  "$B/third_party/glslang/tnt/SPIRV/libSPIRV.a" "$B/third_party/glslang/tnt/glslang/libglslang.a"
  "$B/third_party/glslang/tnt/glslang/OSDependent/Unix/libOSDependent.a"
  "$B/third_party/spirv-tools/source/opt/libSPIRV-Tools-opt.a" "$B/third_party/spirv-tools/source/libSPIRV-Tools.a"
  "$B/third_party/spirv-cross/tnt/libspirv-cross-msl.a" "$B/third_party/spirv-cross/tnt/libspirv-cross-glsl.a"
  "$B/third_party/spirv-cross/tnt/libspirv-cross-core.a"
  "$B/third_party/smol-v/tnt/libsmol-v.a" "$B/third_party/libpng/tnt/libpng.a"
  "$B/third_party/tinyexr/tnt/libtinyexr.a" "$B/third_party/libz/tnt/libz.a"
  "$B/third_party/zstd/tnt/libzstd.a" "$B/libs/utils/libutils.a" "$B/libs/math/libmath.a"
)

OBJ="$FUZZ_DIR/harness"; mkdir -p "$OBJ"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$OBJ/lsan_off.o"
$CC  $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$OBJ/standalone_main.o"

# build_harness <name> <extra source files...>   (harness source: mayhem/<name>.cc or .c)
build_harness() {
  local name="$1"; shift
  local xf=(${HARNESS_EXTRA_FLAGS:-})
  local src="$SRC/mayhem/$name.cc" cc="$CXX" std=("${CXXFLAGS[@]}")
  if [ ! -f "$src" ]; then src="$SRC/mayhem/$name.c"; cc="$CC"; std=(-O1); fi
  local objs=("$OBJ/$name.o") extra
  $cc $HFLAGS "${std[@]}" "${INCS[@]}" -c "$src" -o "$OBJ/$name.o"
  for extra in "$@"; do
    local o="$OBJ/${name}_$(basename "$extra").o"
    $CXX $HFLAGS "${xf[@]}" "${CXXFLAGS[@]}" "${INCS[@]}" -c "$extra" -o "$o"
    objs+=("$o")
  done
  $CXX $HFLAGS $LIB_FUZZING_ENGINE "${objs[@]}" "$OBJ/lsan_off.o" \
      -Wl,--start-group "${LIBS[@]}" -Wl,--end-group -lpthread -ldl -o "$SRC/$name"
  $CXX $HFLAGS "${objs[@]}" "$OBJ/standalone_main.o" "$OBJ/lsan_off.o" \
      -Wl,--start-group "${LIBS[@]}" -Wl,--end-group -lpthread -ldl -o "$SRC/$name-standalone"
}

build_harness fuzz_material_package "$SRC/filament/src/MaterialParser.cpp"
build_harness fuzz_matp_material
build_harness fuzz_uberz
build_harness fuzz_ktx1
build_harness fuzz_image_decoder "$SRC/libs/imageio/src/ImageDecoder.cpp" "$SRC/libs/imageio/src/HDRDecoder.cpp"
# smolv reads opcodes into a `SpvOp` enum by design; the resulting out-of-range enum load aborts
# every run at the first mutated opcode. Only that check is relaxed, and only for smolv.cpp, which
# is compiled here from source instead of linking libsmol-v.a.
HARNESS_EXTRA_FLAGS="-fno-sanitize=enum" build_harness fuzz_smolv "$SRC/third_party/smol-v/source/smolv.cpp"
build_harness fuzz_cgltf

# 3) Upstream gtest suites with the project's NORMAL flags (no sanitizers, no -gdwarf-3).
#    `-include cstring`: test_matp.cpp uses std::memcpy without including <cstring>.
cmake_common "$TEST_DIR"
# test_filamat links the SPIRV-Headers target, which upstream only defines when FILAMENT_SUPPORTS_VULKAN
# is ON (the Vulkan backend itself is not among the targets built here).
cmake -S "$SRC" -B "$TEST_DIR" "${CMAKE_COMMON[@]}" -DFILAMENT_BUILD_TESTING=ON -DFILAMENT_SUPPORTS_VULKAN=ON \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS -include cstring"
cmake --build "$TEST_DIR" -j"$MAYHEM_JOBS" --target test_filaflat test_filamat test_matp test_uberzlib
