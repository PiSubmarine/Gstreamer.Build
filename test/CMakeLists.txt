cmake_minimum_required(VERSION 3.20)

project(${PISUBMARINE_MODULE_NAME}.Test LANGUAGES CXX)

set(${PISUBMARINE_MODULE_NAME}.Test.Sources
        "PiSubmarine/Gstreamer/Build/GstreamerBuildTest.cpp")

enable_testing()

find_package(spdlog CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)

add_library(${PISUBMARINE_MODULE_NAME}.TestSupport INTERFACE)
PiSubmarineInitTarget(${PISUBMARINE_MODULE_NAME}.TestSupport)
target_link_libraries(${PISUBMARINE_MODULE_NAME}.TestSupport INTERFACE ${PISUBMARINE_MODULE_NAME})

PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.TestSupport coreelements)
PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.TestSupport videotestsrc)
PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.TestSupport udp)

add_executable(${PISUBMARINE_MODULE_NAME}.Test ${${PISUBMARINE_MODULE_NAME}.Test.Sources})
PiSubmarineInitTarget(${PISUBMARINE_MODULE_NAME}.Test)

target_link_libraries(${PISUBMARINE_MODULE_NAME}.Test PRIVATE ${PISUBMARINE_MODULE_NAME}.TestSupport)
target_link_libraries(${PISUBMARINE_MODULE_NAME}.Test PRIVATE spdlog::spdlog)
target_link_libraries(${PISUBMARINE_MODULE_NAME}.Test PRIVATE GTest::gtest_main)

PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.Test coreelements)
PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.Test app)
if(WIN32)
    PiSubmarineGstreamerAddPlugin(${PISUBMARINE_MODULE_NAME}.Test qt6d3d11)
endif()
PiSubmarineGstreamerFinalizeCompositionRoot(${PISUBMARINE_MODULE_NAME}.Test)

include(GoogleTest)
if(CMAKE_CROSSCOMPILING)
    gtest_add_tests(TARGET ${PISUBMARINE_MODULE_NAME}.Test)
else()
    gtest_discover_tests(${PISUBMARINE_MODULE_NAME}.Test)
endif()
