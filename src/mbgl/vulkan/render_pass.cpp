#include <mbgl/vulkan/render_pass.hpp>

#include <mbgl/vulkan/command_encoder.hpp>
#include <mbgl/vulkan/renderable_resource.hpp>
#include <mbgl/vulkan/context.hpp>
#include <mbgl/util/logging.hpp>
#include <cstdio>

namespace mbgl {
namespace vulkan {

RenderPass::RenderPass(CommandEncoder& commandEncoder_, const char* name, const gfx::RenderPassDescriptor& descriptor_)
    : descriptor(descriptor_),
      commandEncoder(commandEncoder_) {
    auto& resource = descriptor.renderable.getResource<RenderableResource>();

    resource.bind();

    std::array<vk::ClearValue, 2> clearValues;

    if (descriptor.clearColor.has_value()) {
        auto color = descriptor.clearColor.value().operator std::array<float, 4>();
        clearValues[0].setColor(color);
        fprintf(stderr, "Clear color: %.2f, %.2f, %.2f, %.2f\n", color[0], color[1], color[2], color[3]);
    } else {
        // Default to black if no clear color is specified
        clearValues[0].setColor(std::array<float, 4>{0.0f, 0.0f, 0.0f, 0.0f});
        fprintf(stderr, "Clear color: default black\n");
    }
    clearValues[1].depthStencil.setDepth(descriptor.clearDepth.value_or(1.0f));
    clearValues[1].depthStencil.setStencil(descriptor.clearStencil.value_or(0));

    const auto renderPassBeginInfo = vk::RenderPassBeginInfo()
                                         .setRenderPass(resource.getRenderPass().get())
                                         .setFramebuffer(resource.getFramebuffer().get())
                                         .setRenderArea({{0, 0}, resource.getExtent()})
                                         .setClearValues(clearValues);

    // Debug: Log when we begin a render pass with our framebuffer
    static int renderPassCount = 0;
    if (renderPassCount++ % 10 == 0) {
        fprintf(stderr, "Beginning Vulkan render pass with framebuffer: %p, renderPass: %p, extent: %dx%d\n",
                static_cast<void*>(resource.getFramebuffer().get()),
                static_cast<void*>(resource.getRenderPass().get()),
                resource.getExtent().width,
                resource.getExtent().height);
    }

    pushDebugGroup(name);

    commandEncoder.getCommandBuffer()->beginRenderPass(
        renderPassBeginInfo, vk::SubpassContents::eInline, commandEncoder.getContext().getBackend().getDispatcher());

    commandEncoder.context.performCleanup();
}

RenderPass::~RenderPass() {
    endEncoding();

    popDebugGroup();
}

void RenderPass::endEncoding() {
    fprintf(stderr, "Ending render pass\n");
    commandEncoder.getCommandBuffer()->endRenderPass(commandEncoder.getContext().getBackend().getDispatcher());
}

void RenderPass::clearStencil(uint32_t value) const {
    const auto& resource = descriptor.renderable.getResource<RenderableResource>();
    const auto& extent = resource.getExtent();

    const auto attach = vk::ClearAttachment()
                            .setAspectMask(vk::ImageAspectFlagBits::eStencil)
                            .setClearValue(vk::ClearDepthStencilValue(0.0f, value));

    const auto rect = vk::ClearRect().setBaseArrayLayer(0).setLayerCount(1).setRect(
        {{0, 0}, {extent.width, extent.height}});

    commandEncoder.getCommandBuffer()->clearAttachments(
        attach, rect, commandEncoder.getContext().getBackend().getDispatcher());
}

void RenderPass::pushDebugGroup(const char* name) {
    commandEncoder.pushDebugGroup(name);
}

void RenderPass::popDebugGroup() {
    commandEncoder.popDebugGroup();
}

void RenderPass::addDebugSignpost(const char* name) {
    commandEncoder.getContext().getBackend().insertDebugLabel(commandEncoder.getCommandBuffer().get(), name);
}

} // namespace vulkan
} // namespace mbgl
