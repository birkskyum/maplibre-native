#pragma once

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wstrict-aliasing"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#pragma GCC diagnostic ignored "-Wstrict-aliasing"
#endif

#if defined(WEBGPU_BACKEND_WGPU)
// For wgpu-native backend, use the WebGPU-Cpp wrapper
#include <webgpu.hpp>
#else
// For Dawn backend, use Dawn's C++ wrapper
#include <webgpu/webgpu_cpp.h>
#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
