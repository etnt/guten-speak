# Builds libpocket_tts_raven.so — the Pocket TTS Raven FFI shared library — for
# Android arm64 from the vendored upstream source (third_party/raven, pinned
# revision abd26158). Mirrors upstream's BUILD_SHARED_LIB target: compile
# pocket_tts.cpp with PTT_SHARED_LIB and link ONNX Runtime + SentencePiece.
#
# ONNX Runtime 1.23.2 headers are vendored under third_party/onnxruntime. At
# runtime libpocket_tts_raven.so's only ONNX symbol is OrtGetApiBase (the
# version-stable C API entry); every other ORT call goes through the OrtApi
# function-pointer table returned at runtime, so nothing else is bound at link
# time. We therefore link against a tiny UNVERSIONED OrtGetApiBase stub
# (third_party/onnxruntime/link-stub, SONAME libonnxruntime.so) so our reference
# carries no ELF symbol version. That lets it bind to whatever libonnxruntime.so
# is present at load time — specifically the one the sherpa_onnx plugin already
# ships. NOTE: we must NOT link the real ORT .so: ORT versions its exports
# (OrtGetApiBase@@VERS_x.y.z), and a versioned reference (e.g. @VERS_1.23.2) will
# NOT resolve against a different-versioned runtime lib (sherpa ships 1.27.1).
# The stub is LINK-ONLY and never packaged; sherpa's single libonnxruntime.so is
# the only copy in the APK (shipping our own would collide: two
# lib/<abi>/libonnxruntime.so). SentencePiece v0.2.1 and dr_libs are fetched at
# configure time at the revisions upstream pins.
cmake_minimum_required(VERSION 3.22)

project(pocket_tts_raven_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(RAVEN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/raven")
set(ORT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/onnxruntime")

# ── ONNX Runtime (headers + unversioned link stub) ───────────────────────────
# Headers come from the vendored 1.23.2 SDK (C API is ABI back-compatible, so
# these work against the newer runtime sherpa ships). The link input is the
# UNVERSIONED OrtGetApiBase stub — never packaged; the real libonnxruntime.so
# comes from sherpa_onnx and satisfies our DT_NEEDED at load time.
set(ORT_INCLUDE_DIR "${ORT_DIR}/1.23.2/headers")
set(ORT_LINK_DIR "${ORT_DIR}/link-stub/lib/${ANDROID_ABI}")
set(ORT_LIB "${ORT_LINK_DIR}/libonnxruntime.so")
if(NOT EXISTS "${ORT_LIB}")
  message(FATAL_ERROR "Missing ONNX Runtime link stub for ${ANDROID_ABI}: ${ORT_LIB}")
endif()

# ── SentencePiece (static) + dr_libs (header-only), pinned FetchContent ───────
include(FetchContent)
set(FETCHCONTENT_QUIET OFF)

set(SPM_ENABLE_SHARED OFF CACHE BOOL "" FORCE)
set(SPM_ENABLE_TCMALLOC OFF CACHE BOOL "" FORCE)
set(SPM_PROTOBUF_PROVIDER "internal" CACHE STRING "" FORCE)
set(SPM_ABSL_PROVIDER "internal" CACHE STRING "" FORCE)
set(SPM_ENABLE_NFKC_COMPILE OFF CACHE BOOL "" FORCE)

# Same GCC-14 / cmake-minimum patch upstream applies to SentencePiece v0.2.1.
file(WRITE "${CMAKE_BINARY_DIR}/patch_sentencepiece.cmake" "
file(READ \"\${SOURCE_DIR}/src/sentencepiece_processor.h\" CONTENT)
if(NOT CONTENT MATCHES \"#include <cstdint>\")
    string(REPLACE \"#include <string>\" \"#include <string>\\n#include <cstdint>\" CONTENT \"\${CONTENT}\")
    file(WRITE \"\${SOURCE_DIR}/src/sentencepiece_processor.h\" \"\${CONTENT}\")
    message(STATUS \"Patched sentencepiece_processor.h for GCC 14 compatibility\")
endif()
file(READ \"\${SOURCE_DIR}/CMakeLists.txt\" CMLCONTENT)
string(REGEX REPLACE \"cmake_minimum_required\\\\(VERSION [0-9.]+\\\\)\" \"cmake_minimum_required(VERSION 3.14)\" CMLCONTENT \"\${CMLCONTENT}\")
file(WRITE \"\${SOURCE_DIR}/CMakeLists.txt\" \"\${CMLCONTENT}\")
")

FetchContent_Declare(sentencepiece
  GIT_REPOSITORY https://github.com/google/sentencepiece.git
  GIT_TAG v0.2.1
  GIT_SHALLOW TRUE
  PATCH_COMMAND ${CMAKE_COMMAND} -DSOURCE_DIR=<SOURCE_DIR> -P ${CMAKE_BINARY_DIR}/patch_sentencepiece.cmake
  EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable(sentencepiece)
target_compile_options(sentencepiece-static PRIVATE -w)
set(SENTENCEPIECE_INCLUDE_DIRS "${sentencepiece_SOURCE_DIR}/src")

FetchContent_Declare(dr_libs
  GIT_REPOSITORY https://github.com/mackron/dr_libs.git
  GIT_TAG cd99e2cca5ccb48f8d000f1cd844424dcdbbaf59
  GIT_SHALLOW FALSE
)
FetchContent_MakeAvailable(dr_libs)

# ── FFI shared library ───────────────────────────────────────────────────────
add_library(pocket_tts_raven SHARED
  "${RAVEN_DIR}/src/pocket_tts.cpp"
)

set_target_properties(pocket_tts_raven PROPERTIES OUTPUT_NAME "pocket_tts_raven")
target_compile_definitions(pocket_tts_raven PRIVATE PTT_SHARED_LIB DART_SHARED_LIB)

target_include_directories(pocket_tts_raven PRIVATE
  "${RAVEN_DIR}/include"
  "${RAVEN_DIR}/src"
  "${ORT_INCLUDE_DIR}"
  "${SENTENCEPIECE_INCLUDE_DIRS}"
  "${dr_libs_SOURCE_DIR}"
)

# log: SentencePiece's bundled protobuf-lite calls __android_log_write.
#
# ORT is linked via a search path (-L … -lonnxruntime), NOT by full path. A
# full-path link input makes AGP copy the linked .so into this module's packaged
# libs, which would collide with the libonnxruntime.so that sherpa_onnx already
# ships (two lib/<abi>/libonnxruntime.so → mergeNativeLibs fails). The search-path
# form records DT_NEEDED[libonnxruntime.so] but leaves packaging to sherpa's
# single copy. The resolved file here is the unversioned stub, so our
# OrtGetApiBase reference binds to sherpa's real ORT at load time.
target_link_directories(pocket_tts_raven PRIVATE
  "${ORT_LINK_DIR}"
)
target_link_libraries(pocket_tts_raven PRIVATE
  onnxruntime
  sentencepiece-static
  log
)

# Support Android 15 16k page size. Symbols are left default-visible so the
# extern "C" ptt_* API stays exported for dart:ffi (upstream does the same).
target_link_options(pocket_tts_raven PRIVATE "-Wl,-z,max-page-size=16384")
