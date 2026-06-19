include_guard(GLOBAL)

function(_pisubmarine_gstreamer_initialize_state)
    if(DEFINED PISUBMARINE_GSTREAMER_STATE_INITIALIZED)
        return()
    endif()

    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(PISUBMARINE_GSTREAMER_CORE QUIET IMPORTED_TARGET
                gstreamer-1.0
                gstreamer-video-1.0
                gstreamer-rtp-1.0)
    endif()

    set(PISUBMARINE_GSTREAMER_LIBRARY_DIR "")
    set(PISUBMARINE_GSTREAMER_INCLUDE_DIRS "")
    set(PISUBMARINE_GSTREAMER_LIBRARIES "")

    if(TARGET PkgConfig::PISUBMARINE_GSTREAMER_CORE)
        pkg_get_variable(PISUBMARINE_GSTREAMER_LIBRARY_DIR gstreamer-1.0 libdir)
        set(PISUBMARINE_GSTREAMER_USE_PKGCONFIG TRUE CACHE INTERNAL "")
    else()
        find_path(PISUBMARINE_GSTREAMER_INCLUDE_DIR gst/gst.h PATH_SUFFIXES gstreamer-1.0)
        find_path(PISUBMARINE_GLIB_INCLUDE_DIR glib.h PATH_SUFFIXES glib-2.0)
        find_path(PISUBMARINE_GLIB_CONFIG_INCLUDE_DIR glibconfig.h PATH_SUFFIXES lib/glib-2.0/include)
        find_library(PISUBMARINE_GSTREAMER_LIBRARY NAMES gstreamer-1.0)
        find_library(PISUBMARINE_GSTREAMER_VIDEO_LIBRARY NAMES gstvideo-1.0)
        find_library(PISUBMARINE_GSTREAMER_RTP_LIBRARY NAMES gstrtp-1.0)
        find_library(PISUBMARINE_GLIB_LIBRARY NAMES glib-2.0)
        find_library(PISUBMARINE_GOBJECT_LIBRARY NAMES gobject-2.0)

        if(NOT PISUBMARINE_GSTREAMER_INCLUDE_DIR OR
                NOT PISUBMARINE_GLIB_INCLUDE_DIR OR
                NOT PISUBMARINE_GLIB_CONFIG_INCLUDE_DIR OR
                NOT PISUBMARINE_GSTREAMER_LIBRARY OR
                NOT PISUBMARINE_GSTREAMER_VIDEO_LIBRARY OR
                NOT PISUBMARINE_GSTREAMER_RTP_LIBRARY OR
                NOT PISUBMARINE_GLIB_LIBRARY OR
                NOT PISUBMARINE_GOBJECT_LIBRARY)
            message(FATAL_ERROR
                    "Failed to locate GStreamer development files. "
                    "Install GStreamer development packages through vcpkg or provide discovery hints.")
        endif()

        set(PISUBMARINE_GSTREAMER_INCLUDE_DIRS
                "${PISUBMARINE_GSTREAMER_INCLUDE_DIR}"
                "${PISUBMARINE_GLIB_INCLUDE_DIR}"
                "${PISUBMARINE_GLIB_CONFIG_INCLUDE_DIR}")
        set(PISUBMARINE_GSTREAMER_LIBRARIES
                "${PISUBMARINE_GSTREAMER_LIBRARY}"
                "${PISUBMARINE_GSTREAMER_VIDEO_LIBRARY}"
                "${PISUBMARINE_GSTREAMER_RTP_LIBRARY}"
                "${PISUBMARINE_GLIB_LIBRARY}"
                "${PISUBMARINE_GOBJECT_LIBRARY}")
        get_filename_component(PISUBMARINE_GSTREAMER_LIBRARY_DIR "${PISUBMARINE_GSTREAMER_LIBRARY}" DIRECTORY)
        set(PISUBMARINE_GSTREAMER_USE_PKGCONFIG FALSE CACHE INTERNAL "")
    endif()

    set(PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR "")
    if(PISUBMARINE_GSTREAMER_LIBRARY_DIR)
        set(PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR
                "${PISUBMARINE_GSTREAMER_LIBRARY_DIR}/gstreamer-1.0")
    endif()
    if(NOT PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR)
        set(_candidate_plugin_dirs
                "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TARGET_TRIPLET}/lib/gstreamer-1.0")
        foreach(_candidate_plugin_dir IN LISTS _candidate_plugin_dirs)
            if(EXISTS "${_candidate_plugin_dir}")
                set(PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR "${_candidate_plugin_dir}")
                break()
            endif()
        endforeach()
    endif()

    set(PISUBMARINE_GSTREAMER_LIBRARY_DIR
            "${PISUBMARINE_GSTREAMER_LIBRARY_DIR}" CACHE INTERNAL "")
    set(PISUBMARINE_GSTREAMER_INCLUDE_DIRS
            "${PISUBMARINE_GSTREAMER_INCLUDE_DIRS}" CACHE INTERNAL "")
    set(PISUBMARINE_GSTREAMER_LIBRARIES
            "${PISUBMARINE_GSTREAMER_LIBRARIES}" CACHE INTERNAL "")
    set(PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR
            "${PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR}" CACHE INTERNAL "")
    set(PISUBMARINE_GSTREAMER_STATE_INITIALIZED TRUE CACHE INTERNAL "")
endfunction()

function(PiSubmarineGstreamerInitializeBaseTarget target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "PiSubmarineGstreamerInitializeBaseTarget: '${target}' is not a valid target")
    endif()

    _pisubmarine_gstreamer_initialize_state()

    if(TARGET PkgConfig::PISUBMARINE_GSTREAMER_CORE)
        target_link_libraries("${target}" INTERFACE PkgConfig::PISUBMARINE_GSTREAMER_CORE)
    else()
        target_include_directories("${target}" INTERFACE ${PISUBMARINE_GSTREAMER_INCLUDE_DIRS})
        target_link_libraries("${target}" INTERFACE ${PISUBMARINE_GSTREAMER_LIBRARIES})
    endif()
endfunction()

function(_pisubmarine_gstreamer_normalize_plugin_name plugin_name out_plugin_name)
    if(NOT plugin_name)
        message(FATAL_ERROR "GStreamer plugin name must not be empty")
    endif()

    set(_normalized "${plugin_name}")
    string(REGEX REPLACE "^libgst" "" _normalized "${_normalized}")
    string(REGEX REPLACE "^gst" "" _normalized "${_normalized}")

    if(NOT _normalized)
        message(FATAL_ERROR "Failed to normalize GStreamer plugin name '${plugin_name}'")
    endif()

    set(${out_plugin_name} "${_normalized}" PARENT_SCOPE)
endfunction()

function(_pisubmarine_gstreamer_get_plugin_package plugin_name out_package)
    _pisubmarine_gstreamer_normalize_plugin_name("${plugin_name}" _normalized_plugin_name)
    set(${out_package} "gst${_normalized_plugin_name}" PARENT_SCOPE)
endfunction()

function(_pisubmarine_gstreamer_normalize_link_item item out_target)
    set(_normalized "${item}")
    string(REGEX REPLACE "^\\$<LINK_ONLY:([^>]+)>$" "\\1" _normalized "${_normalized}")
    string(REGEX REPLACE "^\\$<BUILD_INTERFACE:([^>]+)>$" "\\1" _normalized "${_normalized}")

    if(_normalized MATCHES "^\\$<.*>$")
        set(${out_target} "" PARENT_SCOPE)
        return()
    endif()

    if(TARGET "${_normalized}")
        set(${out_target} "${_normalized}" PARENT_SCOPE)
    else()
        set(${out_target} "" PARENT_SCOPE)
    endif()
endfunction()

function(_pisubmarine_gstreamer_collect_plugins_recursive target visited_var plugins_var)
    set(_visited "${${visited_var}}")
    if(";${_visited};" MATCHES ";${target};")
        set(${visited_var} "${_visited}" PARENT_SCOPE)
        set(${plugins_var} "${${plugins_var}}" PARENT_SCOPE)
        return()
    endif()

    list(APPEND _visited "${target}")
    set(${visited_var} "${_visited}")

    get_target_property(_target_plugins "${target}" PISUBMARINE_GSTREAMER_REQUESTED_PLUGINS)
    if(_target_plugins AND NOT _target_plugins STREQUAL "NOTFOUND")
        list(APPEND ${plugins_var} ${_target_plugins})
        list(REMOVE_DUPLICATES ${plugins_var})
    endif()

    foreach(_link_property IN ITEMS LINK_LIBRARIES INTERFACE_LINK_LIBRARIES)
        get_target_property(_linked_items "${target}" "${_link_property}")
        if(NOT _linked_items OR _linked_items STREQUAL "NOTFOUND")
            continue()
        endif()

        foreach(_linked_item IN LISTS _linked_items)
            _pisubmarine_gstreamer_normalize_link_item("${_linked_item}" _linked_target)
            if(_linked_target)
                _pisubmarine_gstreamer_collect_plugins_recursive(
                        "${_linked_target}"
                        ${visited_var}
                        ${plugins_var})
                set(_visited "${${visited_var}}")
            endif()
        endforeach()
    endforeach()

    set(${visited_var} "${${visited_var}}" PARENT_SCOPE)
    set(${plugins_var} "${${plugins_var}}" PARENT_SCOPE)
endfunction()

function(_pisubmarine_gstreamer_collect_static_plugin_library plugin_name out_library)
    if(NOT PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR)
        set(${out_library} "" PARENT_SCOPE)
        return()
    endif()

    _pisubmarine_gstreamer_normalize_plugin_name("${plugin_name}" _normalized_plugin_name)
    set(_plugin_variable_name "PISUBMARINE_GSTREAMER_PLUGIN_${plugin_name}")
    unset(${_plugin_variable_name} CACHE)
    unset(${_plugin_variable_name})

    set(_find_library_suffixes "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    if(UNIX)
        set(CMAKE_FIND_LIBRARY_SUFFIXES "${CMAKE_STATIC_LIBRARY_SUFFIX}")
    endif()
    find_library(${_plugin_variable_name}
            NAMES "gst${_normalized_plugin_name}" "libgst${_normalized_plugin_name}"
            PATHS "${PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR}"
            NO_DEFAULT_PATH)
    set(CMAKE_FIND_LIBRARY_SUFFIXES "${_find_library_suffixes}")

    set(${out_library} "${${_plugin_variable_name}}" PARENT_SCOPE)
endfunction()

function(_pisubmarine_gstreamer_append_windows_library result_variable library_label)
    set(_windows_library_names ${ARGN})
    if(NOT _windows_library_names)
        message(FATAL_ERROR "No library names were provided for '${library_label}'")
    endif()

    unset(PISUBMARINE_GSTREAMER_WINDOWS_SUPPORT_LIBRARY CACHE)
    find_library(PISUBMARINE_GSTREAMER_WINDOWS_SUPPORT_LIBRARY
            NAMES ${_windows_library_names}
            PATHS
                "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TARGET_TRIPLET}/debug/lib"
                "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TARGET_TRIPLET}/lib"
            NO_DEFAULT_PATH)
    if(NOT PISUBMARINE_GSTREAMER_WINDOWS_SUPPORT_LIBRARY)
        message(FATAL_ERROR
                "Failed to locate required Windows GStreamer support library "
                "'${library_label}'.")
    endif()

    list(APPEND ${result_variable} "${PISUBMARINE_GSTREAMER_WINDOWS_SUPPORT_LIBRARY}")
    set(${result_variable} "${${result_variable}}" PARENT_SCOPE)
endfunction()

function(_pisubmarine_gstreamer_link_windows_support_libraries target)
    set(_windows_support_libraries "")

    foreach(_windows_gstreamer_library_spec IN ITEMS
            "gstbase-1.0:gstbase-1.0"
            "gstvideo-1.0:gstvideo-1.0"
            "gstcodecparsers-1.0:gstcodecparsers-1.0"
            "gstcodecs-1.0:gstcodecs-1.0"
            "gstrtp-1.0:gstrtp-1.0"
            "gstaudio-1.0:gstaudio-1.0"
            "gsttag-1.0:gsttag-1.0"
            "gstpbutils-1.0:gstpbutils-1.0"
            "gstnet-1.0:gstnet-1.0"
            "gstd3d11-1.0:gstd3d11-1.0"
            "gstd3dshader-1.0:gstd3dshader-1.0"
            "gstdxva-1.0:gstdxva-1.0"
            "gstwinrt-1.0:gstwinrt-1.0"
            "gio-2.0:gio-2.0"
            "openh264:openh264")
        string(REPLACE ":" ";" _windows_library_parts "${_windows_gstreamer_library_spec}")
        list(GET _windows_library_parts 0 _windows_library_label)
        list(GET _windows_library_parts 1 _windows_library_names)
        _pisubmarine_gstreamer_append_windows_library(
                _windows_support_libraries
                "${_windows_library_label}"
                ${_windows_library_names})
    endforeach()

    foreach(_windows_support_library_spec IN ITEMS
            "gmodule-2.0:gmodule-2.0"
            "intl:intl"
            "iconv:iconv"
            "zlib:zsd;zs;zlibd;zlib"
            "pcre2-8:pcre2-8d;pcre2-8"
            "ffi:ffi")
        string(REPLACE ":" ";" _windows_library_parts "${_windows_support_library_spec}")
        list(GET _windows_library_parts 0 _windows_library_label)
        list(GET _windows_library_parts 1 _windows_library_names)
        _pisubmarine_gstreamer_append_windows_library(
                _windows_support_libraries
                "${_windows_library_label}"
                ${_windows_library_names})
    endforeach()

    list(REMOVE_DUPLICATES _windows_support_libraries)
    target_link_libraries("${target}" PRIVATE
            ${_windows_support_libraries}
            ws2_32
            winmm
            shlwapi
            dnsapi
            iphlpapi
            mf
            mfplat
            mfreadwrite
            mfuuid
            strmiids
            ole32
            runtimeobject
            d3d11
            dxgi)
endfunction()

function(_pisubmarine_gstreamer_link_plugin_extra_dependencies target)
    foreach(_plugin IN LISTS ARGN)
        if(_plugin STREQUAL "app")
            if(PkgConfig_FOUND)
                pkg_check_modules(PISUBMARINE_GSTREAMER_APP QUIET IMPORTED_TARGET gstreamer-app-1.0)
            endif()

            if(TARGET PkgConfig::PISUBMARINE_GSTREAMER_APP)
                target_link_libraries("${target}" PRIVATE PkgConfig::PISUBMARINE_GSTREAMER_APP)
            else()
                find_library(PISUBMARINE_GSTREAMER_APP_LIBRARY
                        NAMES gstapp-1.0
                        PATHS
                            "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TARGET_TRIPLET}/debug/lib"
                            "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TARGET_TRIPLET}/lib"
                        NO_DEFAULT_PATH)
                if(NOT PISUBMARINE_GSTREAMER_APP_LIBRARY)
                    message(FATAL_ERROR
                            "Failed to locate required GStreamer helper library 'gstreamer-app-1.0' "
                            "for plugin 'app'.")
                endif()

                target_link_libraries("${target}" PRIVATE "${PISUBMARINE_GSTREAMER_APP_LIBRARY}")
            endif()
        endif()

        if(_plugin STREQUAL "qt6d3d11")
            find_package(Qt6 CONFIG REQUIRED COMPONENTS Core Gui Network Qml Quick)
            target_link_libraries("${target}" PRIVATE
                    Qt6::Core
                    Qt6::Gui
                    Qt6::Network
                    Qt6::Qml
                    Qt6::Quick)
        endif()
    endforeach()
endfunction()

function(PiSubmarineGstreamerAddPlugin target plugin_name)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "PiSubmarineGstreamerAddPlugin: '${target}' is not a valid target")
    endif()

    _pisubmarine_gstreamer_normalize_plugin_name("${plugin_name}" _normalized_plugin_name)
    _pisubmarine_gstreamer_get_plugin_package("${_normalized_plugin_name}" _unused_package)
    set_property(TARGET "${target}" APPEND PROPERTY
            PISUBMARINE_GSTREAMER_REQUESTED_PLUGINS "${_normalized_plugin_name}")
endfunction()

function(PiSubmarineGstreamerFinalizeCompositionRoot target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "PiSubmarineGstreamerFinalizeCompositionRoot: '${target}' is not a valid target")
    endif()

    get_target_property(_already_finalized "${target}" PISUBMARINE_GSTREAMER_FINALIZED)
    if(_already_finalized)
        return()
    endif()

    _pisubmarine_gstreamer_initialize_state()

    set(_visited "")
    set(_plugins "")
    _pisubmarine_gstreamer_collect_plugins_recursive("${target}" _visited _plugins)
    list(REMOVE_DUPLICATES _plugins)

    target_link_libraries("${target}" PRIVATE PiSubmarine.Gstreamer.Build)

    set(_has_static_plugins FALSE)
    set(_plugin_packages "")
    set(_plugin_libraries "")

    if(_plugins)
        if(PISUBMARINE_GSTREAMER_USE_PKGCONFIG)
            foreach(_plugin IN LISTS _plugins)
                _pisubmarine_gstreamer_get_plugin_package("${_plugin}" _plugin_package)
                list(APPEND _plugin_packages "${_plugin_package}")
            endforeach()

            string(MAKE_C_IDENTIFIER "${target}" _target_identifier)
            set(_pkg_prefix "PISUBMARINE_GSTREAMER_STATIC_${_target_identifier}")
            pkg_check_modules(${_pkg_prefix} QUIET IMPORTED_TARGET ${_plugin_packages})
            if(TARGET "PkgConfig::${_pkg_prefix}")
                set(_has_static_plugins TRUE)
                target_link_libraries("${target}" PRIVATE "PkgConfig::${_pkg_prefix}")
            endif()
        else()
            set(_has_static_plugins TRUE)
            foreach(_plugin IN LISTS _plugins)
                _pisubmarine_gstreamer_collect_static_plugin_library("${_plugin}" _plugin_library)
                if(NOT _plugin_library)
                    set(_has_static_plugins FALSE)
                    message(STATUS
                            "Failed to locate static GStreamer plugin archive '${_plugin}' in "
                            "${PISUBMARINE_GSTREAMER_STATIC_PLUGIN_DIR}; using dynamic plugin discovery instead.")
                    break()
                endif()

                list(APPEND _plugin_libraries "${_plugin_library}")
            endforeach()

            if(_has_static_plugins)
                target_link_libraries("${target}" PRIVATE ${_plugin_libraries})
            endif()
        endif()
    endif()

    if(_has_static_plugins AND WIN32)
        _pisubmarine_gstreamer_link_windows_support_libraries("${target}")
    endif()

    _pisubmarine_gstreamer_link_plugin_extra_dependencies("${target}" ${_plugins})

    set(_plugin_declares "")
    set(_plugin_registrations "")
    set(_plugin_list_text "<none>")
    if(_plugins)
        list(JOIN _plugins ", " _plugin_list_text)
    endif()

    if(_has_static_plugins)
        foreach(_plugin IN LISTS _plugins)
            string(APPEND _plugin_declares "GST_PLUGIN_STATIC_DECLARE(${_plugin});\n")
            string(APPEND _plugin_registrations "            GST_PLUGIN_STATIC_REGISTER(${_plugin});\n")
        endforeach()
    endif()

    string(MAKE_C_IDENTIFIER "${target}" _target_identifier)
    set(_generated_directory
            "${CMAKE_CURRENT_BINARY_DIR}/generated/gstreamer/${_target_identifier}/PiSubmarine/Gstreamer/Build")
    file(MAKE_DIRECTORY "${_generated_directory}")
    set(_generated_template
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/templates/PiSubmarine/Gstreamer/Build/Plugins.cpp.in")
    set(_generated_source "${_generated_directory}/Plugins.cpp")

    set(PISUBMARINE_GSTREAMER_GENERATED_HAS_STATIC_PLUGINS 0)
    if(_has_static_plugins)
        set(PISUBMARINE_GSTREAMER_GENERATED_HAS_STATIC_PLUGINS 1)
    endif()
    set(PISUBMARINE_GSTREAMER_GENERATED_PLUGIN_DECLARES "${_plugin_declares}")
    set(PISUBMARINE_GSTREAMER_GENERATED_PLUGIN_REGISTRATIONS "${_plugin_registrations}")
    set(PISUBMARINE_GSTREAMER_GENERATED_PLUGIN_LIST "${_plugin_list_text}")

    configure_file(
            "${_generated_template}"
            "${_generated_source}"
            @ONLY)

    target_sources("${target}" PRIVATE "${_generated_source}")
    set_property(TARGET "${target}" PROPERTY PISUBMARINE_GSTREAMER_FINALIZED TRUE)
endfunction()
