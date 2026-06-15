#include <memory>
#include <string_view>

#include <gst/gst.h>
#include <gtest/gtest.h>
#include <spdlog/sinks/null_sink.h>
#include <spdlog/spdlog.h>

#include "PiSubmarine/Gstreamer/Build/Plugins.h"

namespace PiSubmarine::Gstreamer::Build::Plugins
{
    namespace
    {
        class GstElementHandle
        {
        public:
            explicit GstElementHandle(GstElement* element)
                : m_Element(element)
            {
            }

            ~GstElementHandle()
            {
                if (m_Element != nullptr)
                {
                    gst_object_unref(GST_OBJECT(m_Element));
                }
            }

            GstElementHandle(const GstElementHandle&) = delete;
            GstElementHandle& operator=(const GstElementHandle&) = delete;

            GstElementHandle(GstElementHandle&& other) noexcept
                : m_Element(other.m_Element)
            {
                other.m_Element = nullptr;
            }

            GstElementHandle& operator=(GstElementHandle&& other) noexcept
            {
                if (this != &other)
                {
                    if (m_Element != nullptr)
                    {
                        gst_object_unref(GST_OBJECT(m_Element));
                    }

                    m_Element = other.m_Element;
                    other.m_Element = nullptr;
                }

                return *this;
            }

            [[nodiscard]] GstElement* Get() const noexcept
            {
                return m_Element;
            }

        private:
            GstElement* m_Element = nullptr;
        };

        [[nodiscard]] std::shared_ptr<spdlog::logger> CreateLogger()
        {
            auto sink = std::make_shared<spdlog::sinks::null_sink_mt>();
            return std::make_shared<spdlog::logger>("PiSubmarine.Gstreamer.Build.Test", std::move(sink));
        }

        void EnsureGstreamerInitialized(const std::shared_ptr<spdlog::logger>& logger)
        {
            GError* error = nullptr;
            ASSERT_TRUE(gst_init_check(nullptr, nullptr, &error));
            if (error != nullptr)
            {
                g_error_free(error);
            }

            RegisterStatic(logger);
        }

        [[nodiscard]] GstElementHandle MakeElement(const char* factoryName)
        {
            return GstElementHandle(gst_element_factory_make(factoryName, nullptr));
        }
    }

    TEST(GstreamerBuildTest, RegistersFactoriesNeededForSimplePipeline)
    {
        const auto logger = CreateLogger();
        EXPECT_FALSE(IsRegistered("videotestsrc"));
        EnsureGstreamerInitialized(logger);
        EXPECT_TRUE(IsRegistered("videotestsrc"));
        EXPECT_TRUE(IsRegistered("coreelements"));
        EXPECT_TRUE(IsRegistered("udp"));
        EXPECT_FALSE(IsRegistered("openh264"));

        auto source = MakeElement("videotestsrc");
        auto sink = MakeElement("fakesink");
        auto* udpSourceFactory = gst_element_factory_find("udpsrc");

        ASSERT_NE(source.Get(), nullptr);
        ASSERT_NE(sink.Get(), nullptr);
        ASSERT_NE(udpSourceFactory, nullptr);
        gst_object_unref(GST_OBJECT(udpSourceFactory));
    }

    TEST(GstreamerBuildTest, PlaysSimplePipelineToEos)
    {
        const auto logger = CreateLogger();
        EnsureGstreamerInitialized(logger);
        EXPECT_TRUE(IsRegistered("videotestsrc"));

        GstElementHandle pipeline(gst_parse_launch("videotestsrc num-buffers=1 ! fakesink", nullptr));
        ASSERT_NE(pipeline.Get(), nullptr);

        ASSERT_NE(gst_element_set_state(pipeline.Get(), GST_STATE_PLAYING), GST_STATE_CHANGE_FAILURE);

        GstBus* bus = gst_element_get_bus(pipeline.Get());
        ASSERT_NE(bus, nullptr);

        GstMessage* message = gst_bus_timed_pop_filtered(
            bus,
            GST_SECOND * 5,
            static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));

        gst_object_unref(GST_OBJECT(bus));
        ASSERT_NE(message, nullptr);

        const auto messageType = GST_MESSAGE_TYPE(message);
        if (messageType == GST_MESSAGE_ERROR)
        {
            GError* error = nullptr;
            gchar* debug = nullptr;
            gst_message_parse_error(message, &error, &debug);
            const auto errorMessage = std::string_view(error != nullptr && error->message != nullptr ? error->message : "");
            if (error != nullptr)
            {
                g_error_free(error);
            }
            if (debug != nullptr)
            {
                g_free(debug);
            }
            gst_message_unref(message);
            FAIL() << "Pipeline failed: " << errorMessage;
        }

        EXPECT_EQ(messageType, GST_MESSAGE_EOS);
        gst_message_unref(message);
        gst_element_set_state(pipeline.Get(), GST_STATE_NULL);
    }

#if defined(_WIN32)
    TEST(GstreamerBuildTest, RegistersWindowsQmlVideoSinkFactory)
    {
        const auto logger = CreateLogger();
        EnsureGstreamerInitialized(logger);
        EXPECT_TRUE(IsRegistered("qt6d3d11"));

        auto sink = MakeElement("qml6d3d11sink");
        ASSERT_NE(sink.Get(), nullptr);
    }
#endif
}
