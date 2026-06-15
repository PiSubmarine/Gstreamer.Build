#pragma once

#include <memory>
#include <string_view>

#include <spdlog/logger.h>

namespace PiSubmarine::Gstreamer::Build
{
    namespace Plugins
    {
        void RegisterStatic(const std::shared_ptr<spdlog::logger>& logger);
        [[nodiscard]] bool IsRegistered(std::string_view plugin) noexcept;
    }
}
