#pragma once

#include <memory>

#include <spdlog/logger.h>

namespace PiSubmarine::Gstreamer::Build
{
    void RegisterStaticPlugins(const std::shared_ptr<spdlog::logger>& logger);
}
