cmake_minimum_required(VERSION 3.19)
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13")

# Override default CMake NATIVE_ARCH_ACTUAL
# https://gitlab.kitware.com/cmake/cmake/-/issues/20893
# https://stackoverflow.com/a/22689917/5531400
if(CMAKE_GENERATOR STREQUAL Xcode)
    set(CMAKE_OSX_ARCHITECTURES "$(ARCHS_STANDARD)")
endif()
set_target_properties(mbgl-core PROPERTIES XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH[variant=Debug] "YES")

set_target_properties(mbgl-core PROPERTIES XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)

if(MLN_WITH_OPENGL)
    find_package(OpenGL REQUIRED)

    target_compile_definitions(
        mbgl-core
        PUBLIC GL_SILENCE_DEPRECATION
    )
    target_sources(
        mbgl-core
        PRIVATE
            ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/gl/headless_backend.cpp
            ${PROJECT_SOURCE_DIR}/platform/darwin/src/gl_functions.cpp ${PROJECT_SOURCE_DIR}/platform/darwin/src/headless_backend_cgl.mm
    )
    target_link_libraries(
        mbgl-core
        PRIVATE OpenGL::GL
    )
endif()

target_sources(
    mbgl-core
    PRIVATE
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/async_task.cpp
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/collator.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/http_file_source.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/image.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/local_glyph_rasterizer.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/logging_nslog.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/native_apple_interface.m
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/nsthread.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/number_format.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/run_loop.cpp
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/string_nsstring.mm
        ${PROJECT_SOURCE_DIR}/platform/darwin/src/timer.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/gfx/headless_backend.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/gfx/headless_frontend.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/layermanager/layer_manager.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/map/map_snapshotter.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/platform/time.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/asset_file_source.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/mbtiles_file_source.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/database_file_source.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/file_source_manager.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/file_source_request.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/local_file_request.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/local_file_source.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/main_resource_loader.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/offline.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/offline_database.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/offline_download.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/online_file_source.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/storage/sqlite3.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/text/bidi.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/util/compression.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/util/monotonic_timer.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/util/png_writer.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/util/thread_local.cpp
        ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/util/utf.cpp
)

target_compile_options(mbgl-core PRIVATE -fobjc-arc)

# FIXME: Should not be needed, but now needed by node because of the headless frontend.
target_include_directories(
    mbgl-core
    PUBLIC ${PROJECT_SOURCE_DIR}/platform/default/include
)

target_include_directories(
    mbgl-core
    PRIVATE
        ${PROJECT_SOURCE_DIR}/platform/darwin/include ${PROJECT_SOURCE_DIR}/platform/darwin/src ${PROJECT_SOURCE_DIR}/platform/macos/src
)

include(${PROJECT_SOURCE_DIR}/vendor/icu.cmake)

target_link_libraries(
    mbgl-core
    PRIVATE
        "-framework AppKit"
        "-framework CoreGraphics"
        "-framework CoreLocation"
        "-framework SystemConfiguration"
        mbgl-vendor-icu
        sqlite3
        z
)

add_subdirectory(${PROJECT_SOURCE_DIR}/bin)
add_subdirectory(${PROJECT_SOURCE_DIR}/expression-test)
add_subdirectory(${PROJECT_SOURCE_DIR}/platform/glfw)
if(MLN_WITH_NODE)
    add_subdirectory(${PROJECT_SOURCE_DIR}/platform/node)
endif()

add_executable(
    mbgl-test-runner
    ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/test/main.cpp
)

target_include_directories(
    mbgl-test-runner
    PUBLIC ${PROJECT_SOURCE_DIR}/include ${PROJECT_SOURCE_DIR}/test/include
)

target_compile_definitions(
    mbgl-test-runner
    PRIVATE WORK_DIRECTORY=${PROJECT_SOURCE_DIR}
)

target_link_libraries(
    mbgl-test-runner
    PRIVATE mbgl-compiler-options -Wl,-force_load mbgl-test
)

add_executable(
    mbgl-benchmark-runner
    ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/benchmark/main.cpp
)

target_include_directories(
    mbgl-benchmark-runner
    PUBLIC ${PROJECT_SOURCE_DIR}/benchmark/include
)

target_link_libraries(
    mbgl-benchmark-runner
    PRIVATE mbgl-compiler-options -Wl,-force_load mbgl-benchmark
)

add_executable(
    mbgl-render-test-runner
    ${PROJECT_SOURCE_DIR}/platform/default/src/mbgl/render-test/main.cpp
)

target_link_libraries(
    mbgl-render-test-runner
    PRIVATE mbgl-compiler-options mbgl-render-test
)

set_property(TARGET mbgl-benchmark-runner PROPERTY FOLDER Executables)
set_property(TARGET mbgl-test-runner PROPERTY FOLDER Executables)
set_property(TARGET mbgl-render-test-runner PROPERTY FOLDER Executables)
set_target_properties(mbgl-benchmark-runner mbgl-test-runner mbgl-render-test-runner PROPERTIES XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH[variant=Debug] "YES")

# Disable benchmarks in CI as they run in VM environment
if(NOT DEFINED ENV{CI})
    add_test(NAME mbgl-benchmark-runner COMMAND mbgl-benchmark-runner WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})
endif()
add_test(
    NAME mbgl-test-runner
    COMMAND
        node
        ${PROJECT_SOURCE_DIR}/test/storage/with-server.js
        ${PROJECT_SOURCE_DIR}/test/storage/server.js
        $<TARGET_FILE:mbgl-test-runner>
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})
