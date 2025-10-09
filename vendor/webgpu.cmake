# WebGPU implementation configuration
# This file handles the integration of either Dawn or wgpu-native

# Set the default WebGPU implementation
set(MLN_WEBGPU_IMPL "dawn" CACHE STRING "WebGPU backend implementation (dawn or wgpu)")
set_property(CACHE MLN_WEBGPU_IMPL PROPERTY STRINGS dawn wgpu)

if(NOT MLN_WITH_WEBGPU)
    return()
endif()

# Validate WebGPU implementation choice
if(NOT MLN_WEBGPU_IMPL MATCHES "^(dawn|wgpu)$")
    message(FATAL_ERROR
        "Invalid MLN_WEBGPU_IMPL value: '${MLN_WEBGPU_IMPL}'. "
        "Must be either 'dawn' or 'wgpu'.")
endif()

message(STATUS "WebGPU backend implementation: ${MLN_WEBGPU_IMPL}")

# The actual integration is done in the main CMakeLists.txt by including
# either vendor/dawn.cmake or vendor/wgpu.cmake based on MLN_WEBGPU_IMPL
