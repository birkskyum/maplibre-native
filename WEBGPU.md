# WebGPU Backend Implementation

MapLibre Native supports WebGPU rendering with two backend implementations:

## Supported Backends

### 1. Dawn (Default)
- **Implementation**: Google's WebGPU reference implementation in C++
- **Repository**: https://dawn.googlesource.com/dawn
- **License**: BSD-3-Clause
- **Native APIs**:
  - Metal on macOS/iOS
  - Vulkan on Linux/Android
  - D3D12 on Windows
- **Build**: Automatically fetched and compiled by CMake (no additional setup required)

### 2. wgpu-native
- **Implementation**: Mozilla/gfx-rs WebGPU implementation in Rust
- **Repository**: https://github.com/gfx-rs/wgpu-native
- **License**: MIT / Apache-2.0
- **Native APIs**:
  - Metal on macOS/iOS
  - Vulkan on Linux/Windows/Android
  - DX12 on Windows
  - GLES on Linux/Android (fallback)
- **Build**: Requires Rust toolchain; automatically compiled via cargo or use pre-built binaries

## Quick Start

### Using Dawn (Recommended for most users)

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/maplibre/maplibre-native.git
cd maplibre-native

# Configure (Dawn is fetched automatically)
cmake --preset macos-webgpu  # or linux-webgpu

# Build
cmake --build build-macos-webgpu
```

### Using wgpu-native

**Prerequisites:**
1. Install Rust: https://rustup.rs/
2. Initialize the wgpu-native submodule:
   ```bash
   git submodule update --init --recursive vendor/wgpu-native
   ```

**Build:**
```bash
# Configure
cmake --preset macos-wgpu  # or linux-wgpu

# Build (will automatically run cargo build for wgpu-native)
cmake --build build-macos-wgpu
```

**Using pre-built wgpu-native binaries (optional):**

Download from https://github.com/gfx-rs/wgpu-native/releases and extract to:
- macOS ARM64: `vendor/wgpu-native/target/aarch64-apple-darwin/release/`
- macOS x64: `vendor/wgpu-native/target/x86_64-apple-darwin/release/`
- Linux x64: `vendor/wgpu-native/target/x86_64-unknown-linux-gnu/release/`
- Windows x64: `vendor/wgpu-native/target/x86_64-pc-windows-msvc/release/`

## Manual Configuration

Both backends can be explicitly selected via CMake variables:

```bash
# Using Dawn
cmake -DMLN_WITH_WEBGPU=ON -DMLN_WEBGPU_IMPL=dawn <other-options> /path/to/source

# Using wgpu-native
cmake -DMLN_WITH_WEBGPU=ON -DMLN_WEBGPU_IMPL=wgpu <other-options> /path/to/source
```

## Platform Support

| Platform | Dawn | wgpu-native | Native API |
|----------|------|-------------|------------|
| macOS    | ✅   | ✅          | Metal      |
| iOS      | ✅   | ✅          | Metal      |
| Linux    | ✅   | ✅          | Vulkan     |
| Windows  | ✅   | ✅          | D3D12/Vulkan |
| Android  | ✅   | ✅          | Vulkan     |

## Backend Selection Criteria

### Choose Dawn if:
- You want the "official" Google WebGPU implementation
- You prefer C++ over Rust dependencies
- You're targeting Chrome/Chromium embedding
- You don't want to install Rust toolchain

### Choose wgpu-native if:
- You prefer Rust-based implementations
- You want potentially smaller binaries and better performance
- You're targeting Firefox embedding
- You need GLES fallback support on Linux

## Implementation Details

### Code Architecture

The WebGPU rendering code in MapLibre Native is **backend-agnostic** with conditional compilation for API differences:

- **Public API**: Uses standard WebGPU C API (`webgpu/webgpu.h`)
- **Location**: `src/mbgl/webgpu/` and `include/mbgl/webgpu/`
- **Backend selection**: Happens at build time via CMake
- **No runtime switching**: Backend is determined at compile time
- **Conditional compilation**: Uses `#if defined(WEBGPU_BACKEND_WGPU)` for backend-specific code paths

Most WebGPU rendering code works identically with both backends, but some platform-specific initialization and handle management differs between Dawn's C++ API and wgpu-native's C++ wrapper.

### Header Compatibility

The code includes headers conditionally based on the backend:

**wgpu_cpp_compat.hpp** (`include/mbgl/webgpu/wgpu_cpp_compat.hpp`):
```cpp
#if defined(WEBGPU_BACKEND_WGPU)
// For wgpu-native backend, use the WebGPU-Cpp wrapper
#include <webgpu.hpp>
#else
// For Dawn backend, use Dawn's C++ wrapper
#include <webgpu/webgpu_cpp.h>
#endif
```

**Standard include order**:
1. `<mbgl/webgpu/wgpu_cpp_compat.hpp>` - Backend-specific C++ bindings
2. `<webgpu/webgpu.h>` - Standard WebGPU C API (both backends)

### C++ Wrapper Integration

**Dawn**: Provides its own C++ wrapper (`webgpu_cpp.h`) with the WebGPU headers.

**wgpu-native**: Uses the WebGPU-Cpp wrapper (https://github.com/eliemichel/WebGPU-Cpp) for C++ bindings:
- Repository: `vendor/webgpu-cpp` (submodule)
- Implementation: `src/mbgl/webgpu/webgpu_cpp_impl.cpp` (defines `WEBGPU_CPP_IMPLEMENTATION`)
- Generated for: wgpu-native v27.0.2.0

### API Differences Handled via Conditional Compilation

Despite both backends implementing the WebGPU standard, there are minor API differences in the C++ wrappers:

| Feature | Dawn | wgpu-native | Conditional Compilation |
|---------|------|-------------|-------------------------|
| Instance creation | `dawn::native::Instance` | `wgpu::createInstance()` | `WEBGPU_BACKEND_WGPU` |
| Method naming | PascalCase (`CreateTexture`, `GetQueue`) | camelCase (`createTexture`, `getQueue`) | `WEBGPU_BACKEND_WGPU` |
| Handle access | `.Get()` method | Direct cast operators | `WEBGPU_BACKEND_WGPU` |
| Handle wrapping | `::Acquire()` | Direct construction | `WEBGPU_BACKEND_WGPU` |
| Enum naming | `e2D`, `e2DArray` | `_2D`, `_2DArray` | `WEBGPU_BACKEND_WGPU` |
| Descriptor labels | Required in C++ API | Not exposed in wrapper | `WEBGPU_BACKEND_WGPU` |
| Device ticking | `wgpuDeviceTick()` available | Not in standard API | `!defined(WEBGPU_BACKEND_WGPU)` |

**Example** (from `src/mbgl/webgpu/headless_backend.cpp`):
```cpp
#if defined(WEBGPU_BACKEND_WGPU)
    // wgpu-native: camelCase, direct casts
    wgpu::InstanceDescriptor instanceDesc = {};
    impl->instance = wgpu::createInstance(instanceDesc);
    impl->adapter = impl->instance.requestAdapter(adapterOpts);
    impl->device = impl->adapter.requestDevice(deviceDesc);
    impl->queue = impl->device.getQueue();
    setDevice(static_cast<WGPUDevice>(impl->device));
#else
    // Dawn: PascalCase, .Get() method, Dawn-specific APIs
    impl->instance = std::make_unique<dawn::native::Instance>(&instanceDesc);
    auto adapters = impl->instance->EnumerateAdapters();
    WGPUDevice rawDevice = adapters[0].CreateDevice(&deviceDesc);
    impl->device = wgpu::Device::Acquire(rawDevice);
    impl->queue = impl->device.GetQueue();
    setDevice(impl->device.Get());
#endif
```

**Files with conditional compilation**:
- `src/mbgl/webgpu/headless_backend.cpp` - Backend initialization (lines 118-193)
- `src/mbgl/webgpu/render_pass.cpp` - Texture view handling (lines 74-149)
- `src/mbgl/webgpu/offscreen_texture.cpp` - Device ticking (line 148)
- `include/mbgl/webgpu/wgpu_cpp_compat.hpp` - Header selection

### Build System Integration

- `CMakeLists.txt` (line ~1413-1428): Main integration point
- `vendor/webgpu.cmake`: Backend selection logic
- `vendor/dawn.cmake`: Dawn-specific configuration
- `vendor/wgpu.cmake`: wgpu-native-specific configuration

## Known Limitations

### wgpu-native Specific

**wgpuInstanceWaitAny not implemented** (✅ FIXED):
- **Issue**: `wgpuInstanceWaitAny` is not yet implemented in wgpu-native v27.0.2.0
- **Solution**: Implemented polling-based buffer mapping using `wgpuDevicePoll` with `WGPUCallbackMode_AllowProcessEvents`
- **Implementation**: `src/mbgl/webgpu/offscreen_texture.cpp:208-239`
- **Status**: ✅ Working - render tests now pass with wgpu-native backend

**WGPU_FALSE constant not defined** (✅ FIXED):
- **Issue**: wgpu-native doesn't define `WGPU_FALSE` macro
- **Solution**: Code uses `false` directly instead
- **Location**: render_pass.cpp lines 112, 122

**Swizzle assignment not allowed** (✅ FIXED):
- **Issue**: wgpu-native shader validator rejects assignments to swizzles (`lighting.rgb += ...`)
- **Reason**: More strict WGSL spec compliance - swizzle assignments are not valid WGSL
- **Solution**: Reconstruct full vec4 instead: `lighting = vec4<f32>(lighting.rgb + lit, lighting.a)`
- **Location**: include/mbgl/shaders/webgpu/fill_extrusion.hpp:310

### Dawn Specific

No known limitations at this time. Dawn is more mature and fully implements the WebGPU specification.

### General WebGPU Limitations

- **No runtime backend switching**: Backend choice is compile-time only
- **Native API version dependencies**: Requires Metal 2+ on macOS, Vulkan 1.1+ on Linux, D3D12 on Windows
- **Shader compilation**: WGSL shaders are compiled at runtime (startup cost)

## Troubleshooting

### Dawn build fails

**Issue**: Dawn fails to fetch or build
**Solution**:
- Check internet connectivity (Dawn is fetched from Google's servers)
- Clear CMake cache: `rm -rf build-macos-webgpu && cmake --preset macos-webgpu`
- Manually fetch Dawn: `git submodule update --init --recursive vendor/dawn`

### wgpu-native: cargo not found

**Issue**: `cargo: command not found`
**Solution**: Install Rust toolchain from https://rustup.rs/

### wgpu-native: build fails on macOS

**Issue**: Linker errors about missing Metal framework
**Solution**: Ensure Xcode Command Line Tools are installed: `xcode-select --install`

### wgpu-native: slow build

**Issue**: First cargo build takes a long time
**Solution**:
- Use pre-built binaries (see above)
- Or be patient - subsequent builds are incremental and fast

### Runtime: Cannot create WebGPU device

**Issue**: Application fails to initialize WebGPU device
**Possible causes**:
- Graphics drivers out of date (update GPU drivers)
- Backend not supported on platform (check platform support table)
- Vulkan/Metal/D3D12 runtime missing

## Testing

Run the test suite with WebGPU backend:

```bash
# Dawn
cmake --preset macos-webgpu
cmake --build build-macos-webgpu
./build-macos-webgpu/mbgl-test-runner

# wgpu-native
cmake --preset macos-wgpu
cmake --build build-macos-wgpu
./build-macos-wgpu/mbgl-test-runner
```

Run render tests:
```bash
./build-macos-webgpu/mbgl-render-test-runner --manifestPath metrics/macos-xcode11-release-style.json
```

## Contributing

When contributing WebGPU rendering code:

1. **Prefer standard WebGPU C API** - Use the C API (`wgpu*` functions) when possible to avoid backend differences
2. **Use conditional compilation when necessary** - For C++ API differences, use `#if defined(WEBGPU_BACKEND_WGPU)`
3. **Test both backends** - Build and test with both `macos-webgpu` (Dawn) and `macos-wgpu` (wgpu-native) presets
4. **Follow existing patterns** - See conditional compilation examples in:
   - `src/mbgl/webgpu/headless_backend.cpp` - Device/adapter initialization
   - `src/mbgl/webgpu/render_pass.cpp` - Handle wrapping and casting
   - `include/mbgl/webgpu/wgpu_cpp_compat.hpp` - Header selection pattern
5. **Update documentation** - Keep this file and CLAUDE.md updated with any new conditional compilation patterns

### Pattern for Backend-Specific Code

```cpp
#if defined(WEBGPU_BACKEND_WGPU)
    // wgpu-native specific code
    // - Use camelCase methods: createTexture(), getQueue()
    // - Direct cast: static_cast<WGPUDevice>(device)
    // - Direct construction: wgpu::TextureView(handle)
#else
    // Dawn specific code
    // - Use PascalCase methods: CreateTexture(), GetQueue()
    // - Use .Get() for handles: device.Get()
    // - Use ::Acquire(): wgpu::TextureView::Acquire(handle)
#endif
```

## Resources

- [WebGPU Specification](https://www.w3.org/TR/webgpu/)
- [Dawn Documentation](https://dawn.googlesource.com/dawn/+/HEAD/docs/)
- [wgpu Documentation](https://wgpu.rs/)
- [Learn WebGPU](https://eliemichel.github.io/LearnWebGPU/)
- [WebGPU Headers](https://github.com/webgpu-native/webgpu-headers)

## License Notes

- **Dawn**: BSD-3-Clause (see `vendor/dawn/LICENSE`)
- **wgpu-native**: MIT OR Apache-2.0 (see `vendor/wgpu-native/LICENSE.MIT` and `LICENSE.APACHE`)
- **MapLibre Native**: BSD-2-Clause (see `LICENSE.md`)
