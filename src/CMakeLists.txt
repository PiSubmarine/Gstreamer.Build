include("${PISUBMARINE_BUILD_SYSTEM}")

find_package(spdlog CONFIG REQUIRED)

message("Adding library: ${PISUBMARINE_MODULE_NAME}")
add_library(${PISUBMARINE_MODULE_NAME} INTERFACE)
target_include_directories(${PISUBMARINE_MODULE_NAME}
        INTERFACE "../public")
PiSubmarineInitTarget(${PISUBMARINE_MODULE_NAME})

target_link_libraries(${PISUBMARINE_MODULE_NAME}
        INTERFACE spdlog::spdlog)

PiSubmarineGstreamerInitializeBaseTarget(${PISUBMARINE_MODULE_NAME})
