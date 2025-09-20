#pragma once

#include <cstdlib>

namespace mbgl {
namespace webgpu {

inline bool isVerboseLoggingEnabled() {
    static const bool enabled = [] {
        if (const char* env = std::getenv("MLN_WEBGPU_TRACE")) {
            return env[0] != '\0' && env[0] != '0';
        }
        return false;
    }();
    return enabled;
}

} // namespace webgpu
} // namespace mbgl

