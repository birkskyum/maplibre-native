# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MapLibre Native is a free and open-source library for GPU-accelerated vector tile rendering across multiple platforms (Android, iOS, macOS, Node.js, Qt, Linux, Windows). The project uses a monorepo structure housing core C++ code and platform-specific SDK bindings.

## Build System & Common Commands

### Prerequisites

Clone with submodules:
```bash
git clone --recurse-submodules https://github.com/maplibre/maplibre-native.git
```

Install pre-commit hooks:
```bash
pre-commit install
```

### iOS Development (Bazel)

Generate Xcode project for Metal renderer:
```bash
bazel run //platform/ios:xcodeproj --@rules_xcodeproj//xcodeproj:extra_common_flags="--//:renderer=metal"
xed platform/ios/MapLibre.xcodeproj
```

Run iOS tests:
```bash
bazel test //platform/ios/test:ios_test --test_output=errors --//:renderer=metal
```

Build example app:
```bash
bazel build //platform/ios/app-swift:MapLibreApp --//:renderer=metal
```

iOS can also be built with CMake:
```bash
cmake --preset ios
cmake --build build-ios --target mbgl-core ios-sdk-static app
```

### Android Development (Gradle)

Open `platform/android` in Android Studio, or use Make commands from `platform/android/`:

Build SDK (default arm-v7):
```bash
make android-lib  # or android-lib-arm-v8, android-lib-x86, android-lib-x86-64
```

Run unit tests:
```bash
make run-android-unit-test RENDERER=opengl  # or RENDERER=vulkan
```

Run instrumentation tests:
```bash
make run-android-ui-test-arm-v7
```

Build release package:
```bash
make apackage BUILDTYPE=Release RENDERER=opengl  # or vulkan
```

Code style checks:
```bash
make android-check  # runs ktlint, checkstyle, and lint
```

### Node.js Development (CMake)

```bash
# macOS with Metal
cmake --preset macos-metal-node -DCMAKE_BUILD_TYPE=Release
cmake --build build -j $(sysctl -n hw.ncpu)

# Linux with OpenGL
cmake --preset linux-opengl-node -DCMAKE_BUILD_TYPE=Release
cmake --build build -j $(nproc)

# Windows with OpenGL
cmake --preset windows-opengl-node -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Run tests
cd platform/node
npm ci --ignore-scripts
npm test
```

### CMake Build Options

Key CMake options (set with `-DMLN_WITH_<OPTION>=ON/OFF`):
- `MLN_WITH_OPENGL` - Build with OpenGL renderer
- `MLN_WITH_VULKAN` - Build with Vulkan renderer
- `MLN_WITH_METAL` - Build with Metal renderer
- `MLN_WITH_WEBGPU` - Build with WebGPU renderer
- `MLN_WITH_QT` - Build Qt bindings
- `MLN_WITH_NODE` - Build Node.js bindings
- `MLN_WITH_GLFW` - Build GLFW platform (for desktop testing)
- `MLN_WITH_PMTILES` - Build with PMTiles support (default ON)
- `MLN_WITH_COVERAGE` - Enable code coverage collection
- `MLN_WITH_SANITIZER` - Use sanitizer (address|thread|undefined)

### Testing

Run C++ unit tests:
```bash
# After building with CMake
./build/mbgl-test-runner
```

Run render tests (image diff based):
```bash
./build/mbgl-render-test-runner --manifestPath metrics/linux-clang8-release-style.json
# Generates HTML report with visualized results
```

Run expression tests:
```bash
# Tests for MapLibre Style Spec expressions
# Located in expression-test directory
```

### Code Formatting

Pre-commit runs automatically on commit, or manually:
```bash
pre-commit run --all-files

# Individual formatters:
pre-commit run clang-format --all-files  # C++ files
pre-commit run swiftformat --all-files   # Swift files (iOS)
cd rustutils && cargo fmt --all          # Rust files
```

## Architecture

### Core C++ Structure

- **`include/mbgl/`** - Public C++ API headers (exported interface)
- **`src/mbgl/`** - Private implementation files and headers
  - Key subdirectories: `map`, `style`, `renderer`, `storage`, `platform`, `text`, `tile`, `util`, `gfx`, `gl`, `mtl`, `vulkan`, `webgpu`

### Platform SDKs

- **`platform/android/`** - Android SDK (Gradle build, Kotlin/Java)
- **`platform/ios/`** - iOS SDK (Bazel/Xcode, Swift/Objective-C)
- **`platform/macos/`** - macOS SDK
- **`platform/node/`** - Node.js bindings
- **`platform/qt/`** - Qt bindings
- **`platform/darwin/`** - Shared code for iOS/macOS
- **`platform/default/`** - Default implementations shared across platforms
- **`platform/glfw/`** - GLFW-based test application (`mbgl-glfw`)
- **`platform/linux/`, `platform/windows/`** - Linux and Windows specific code

### Key Components

**Immutability Pattern**: Core design uses immutable `Layer::Impl`, `Source::Impl` objects via `Immutable<T>` template. Mutable public API (`Layer`, `Source`) creates new immutable copies on modification. This enables safe multi-threading and efficient style diffing.

**Style System**: Implements [MapLibre Style Spec](https://maplibre.org/maplibre-style-spec/). Runtime styling API is auto-generated from the style specification. Style changes are communicated to render thread via immutable snapshots.

**Threading Model**:
- Main thread: handles `Map` API, owns active `Style`, renders map
- Worker threads: 4 per `Style`, handle vector tile parsing, text layout, OpenGL buffer generation
- FileSource thread: handles network requests and SQLite I/O for offline/caching

**Render Objects**: Parallel hierarchy to style objects (`RenderStyle`, `RenderLayer`, `RenderSource`) that contain computed values and loaded tiles. Updated each frame via style diffing against immutable snapshots.

### Other Directories

- **`benchmark/`** - Performance tests using Google Benchmark
- **`bin/`** - Utility tools: `mbgl-cache`, `mbgl-offline`, `mbgl-render`
- **`expression-test/`** - Expression feature tests
- **`metrics/`** - Test manifests and ground truth images for render tests
- **`render-test/`** - Image diff-based render testing infrastructure
- **`test/`** - C++ unit tests (run via `mbgl-test-runner`)
- **`vendor/`** - Third-party dependencies (submodules)
- **`shaders/`** - GLSL/MSL/WGSL shader source files
- **`scripts/`** - Build and CI helper scripts

## Renderer Backends

The project supports multiple rendering backends:
- **OpenGL** - Legacy renderer, widely supported
- **Vulkan** - Modern graphics API for Android/Linux
- **Metal** - macOS/iOS native renderer
- **WebGPU** - Modern cross-platform graphics (using Dawn or wgpu-native)

When making changes to rendering code, consider which backends are affected. Renderer abstraction is in `include/mbgl/gfx/` and implementations in `src/mbgl/gl/`, `src/mbgl/mtl/`, `src/mbgl/vulkan/`, `src/mbgl/webgpu/`.

## WebGPU Development (Current Branch: webgpu-backend)

This branch is actively developing WebGPU renderer support. The codebase supports two WebGPU backend implementations with conditional compilation for API differences.

### Dawn (Google's WebGPU implementation - Default)
```bash
# Configure with Dawn backend (default)
cmake --preset macos-webgpu
# Or explicitly:
cmake -DMLN_WITH_WEBGPU=ON -DMLN_WEBGPU_IMPL=dawn ...

# Build
cmake --build build-macos-webgpu -j $(sysctl -n hw.ncpu)
```

Dawn is automatically fetched and built by CMake. It provides a C++ WebGPU implementation with support for multiple native graphics APIs (Metal on macOS, Vulkan on Linux, D3D12 on Windows).

### wgpu-native (Rust WebGPU implementation)
```bash
# Configure with wgpu-native backend
cmake --preset macos-wgpu
# Or explicitly:
cmake -DMLN_WITH_WEBGPU=ON -DMLN_WEBGPU_IMPL=wgpu ...

# Build (automatically compiles wgpu-native via cargo)
cmake --build build-macos-wgpu -j $(sysctl -n hw.ncpu)
```

**Prerequisites for wgpu-native:**
- Rust toolchain installed (https://rustup.rs/)
- wgpu-native submodule initialized: `git submodule update --init --recursive vendor/wgpu-native`
- WebGPU-Cpp submodule initialized: `git submodule update --init --recursive vendor/webgpu-cpp`

The build system will automatically compile wgpu-native using cargo. Alternatively, you can download pre-built binaries from https://github.com/gfx-rs/wgpu-native/releases and place them in `vendor/wgpu-native/target/release/`.

### Implementation Status

**What works:**
- ✅ Build system integration for both backends
- ✅ WebGPU C++ API abstraction with conditional compilation
- ✅ Backend initialization (device, adapter, queue creation)
- ✅ Texture and buffer creation
- ✅ Render pass creation and encoding
- ✅ Basic rendering (tested with both backends)
- ✅ Headless rendering and buffer readback (both backends)
- ✅ Render tests pass on both Dawn and wgpu-native

**Implementation notes:**
- wgpu-native: Uses polling-based buffer mapping (`wgpuDevicePoll`) instead of `wgpuInstanceWaitAny`
- Dawn: Uses newer `wgpuInstanceWaitAny` API for synchronous buffer mapping
- Both approaches work correctly for render tests

**Status:**
- ✅ wgpu-native: Fully functional with polling workaround (v27.0.2.0)
- ✅ Dawn: Fully functional with all WebGPU features

### Conditional Compilation Pattern

The WebGPU code uses conditional compilation to handle API differences between Dawn and wgpu-native:

**Macro**: `#if defined(WEBGPU_BACKEND_WGPU)`

**Key files with backend-specific code:**
- `include/mbgl/webgpu/wgpu_cpp_compat.hpp` - Header selection (webgpu.hpp vs webgpu_cpp.h)
- `src/mbgl/webgpu/webgpu_cpp_impl.cpp` - WebGPU-Cpp implementation (wgpu-native only)
- `src/mbgl/webgpu/headless_backend.cpp` - Device/adapter initialization
- `src/mbgl/webgpu/render_pass.cpp` - Texture view handle management
- `src/mbgl/webgpu/offscreen_texture.cpp` - Device ticking (Dawn-specific)

**Pattern example:**
```cpp
#if defined(WEBGPU_BACKEND_WGPU)
    // wgpu-native: camelCase, direct casts, WebGPU-Cpp wrapper
    impl->device = impl->adapter.requestDevice(deviceDesc);
    impl->queue = impl->device.getQueue();
    setDevice(static_cast<WGPUDevice>(impl->device));
#else
    // Dawn: PascalCase, .Get() method, dawn::native API
    WGPUDevice rawDevice = adapter.CreateDevice(&deviceDesc);
    impl->device = wgpu::Device::Acquire(rawDevice);
    impl->queue = impl->device.GetQueue();
    setDevice(impl->device.Get());
#endif
```

### Choosing Between Dawn and wgpu-native

- **Dawn**:
  - ✅ Fully functional including render tests
  - ✅ C++ implementation, no Rust dependency
  - ✅ Officially supported by Google/Chrome
  - ✅ Latest WebGPU API features (InstanceWaitAny)
  - ❌ Larger binary size, longer build times

- **wgpu-native**:
  - ✅ Fully functional including render tests (using polling)
  - ✅ Rust implementation, smaller and potentially faster
  - ✅ Used by Firefox
  - ✅ Builds successfully on macOS, Linux, Windows
  - ❌ Requires Rust toolchain
  - ⚠️ Uses polling instead of InstanceWaitAny for buffer mapping

**Recommendation**: Both backends are now fully functional. Choose based on your preferences:
- **Dawn**: If you prefer C++ dependencies and want the latest WebGPU API
- **wgpu-native**: If you prefer Rust-based implementations or need smaller binaries

**Configuration option:**
```bash
-DMLN_WEBGPU_IMPL=dawn    # Use Dawn (default)
-DMLN_WEBGPU_IMPL=wgpu    # Use wgpu-native (fully functional)
```

**See also:** `WEBGPU.md` for comprehensive WebGPU backend documentation.

## Style Code Generation

Android style code is auto-generated from the style specification:
```bash
node platform/android/scripts/generate-style-code.mjs
```

This must be run when style specification changes to update PropertyFactory and layer classes.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `android-ci.yml` - Android builds and tests (OpenGL and Vulkan)
- `ios-ci.yml` - iOS builds, tests, and release process
- `node-ci.yml` - Node.js builds and tests across platforms
- `qt-ci.yml` - Qt builds
- `pr-linux-tests.yml` - Linux C++ tests on PRs

CI runs format checks via pre-commit, builds for multiple architectures, runs unit tests, instrumentation tests, and render tests.

## Code Style

- C++: Use clang-format (configured in `.clang-format`)
- Swift: Use SwiftFormat (version 5.8)
- Kotlin/Java: Follow Android checkstyle rules
- Rust: Standard rustfmt
- Always include headers as `#include <mbgl/___/___.hpp>`
- Use immutable patterns for thread-safe code where possible

## Documentation

- Developer docs: https://maplibre.org/maplibre-native/docs/book/
- Android API: https://maplibre.org/maplibre-native/android/api/
- iOS API: https://maplibre.org/maplibre-native/ios/latest/documentation/maplibre/
- Style Spec: https://maplibre.org/maplibre-style-spec/
- Read `ARCHITECTURE.md` for deeper implementation details
