#pragma once

#include <mbgl/gfx/drawable_data.hpp>
#include <mbgl/geometry/line_atlas.hpp>

#include <memory>
#include <vector>

namespace mbgl {

namespace gfx {

class LineDrawableData : public DrawableData {
public:
    LineDrawableData(LinePatternCap linePatternCap_,
                     std::vector<float> dashFromOverride_ = {},
                     std::vector<float> dashToOverride_ = {})
        : linePatternCap(linePatternCap_),
          dashFromOverride(std::move(dashFromOverride_)),
          dashToOverride(std::move(dashToOverride_)) {}

    LinePatternCap linePatternCap;
    std::vector<float> dashFromOverride;
    std::vector<float> dashToOverride;
};

using UniqueLineDrawableData = std::unique_ptr<LineDrawableData>;

} // namespace gfx
} // namespace mbgl
