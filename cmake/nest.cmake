
# GLOBAL STATE
################################################################################

include(FetchContent)

set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/.nest/vendor")

# Tracks all external deps added via nest_DEP
set(_g_nest_EXTERNAL "" CACHE INTERNAL "Global external-dependencies list")
set(_g_nest_EXTERNAL_CONFIG "" CACHE INTERNAL "External deps needing find_dependency in config file")

# Version conflict tracking
set(_g_nest_DEP_NAMES "" CACHE INTERNAL "Dependency names registered via nest_DEP")
set(_g_nest_DEP_VERSIONS "" CACHE INTERNAL "Dependency versions registered via nest_DEP")
set(_g_nest_DEP_PROJECTS "" CACHE INTERNAL "Projects that registered each dependency")

# Lockfile helpers


function(_nest_LOCKFILE_GET dep_name key out_var)
    if(EXISTS "${CMAKE_SOURCE_DIR}/nest.lock")
        file(READ "${CMAKE_SOURCE_DIR}/nest.lock" l_json_raw)
        string(STRIP "${l_json_raw}" l_json)
    else()
        set(l_json "{}")
    endif()
    string(JSON l_val ERROR_VARIABLE l_err GET "${l_json}" "${dep_name}" "${key}")
    if(l_err)
        set(${out_var} "" PARENT_SCOPE)
    else()
        set(${out_var} "${l_val}" PARENT_SCOPE)
    endif()
endfunction()


function(_nest_LOCKFILE_SET dep_name version sha256 url)
    if(EXISTS "${CMAKE_SOURCE_DIR}/nest.lock")
        file(READ "${CMAKE_SOURCE_DIR}/nest.lock" l_json_raw)
        string(STRIP "${l_json_raw}" l_json)
    else()
        set(l_json "{}")
    endif()
    string(JSON l_json ERROR_VARIABLE l_err
        SET "${l_json}" "${dep_name}" "{}")
    string(JSON l_json ERROR_VARIABLE l_err
        SET "${l_json}" "${dep_name}" "version" "\"${version}\"")
    string(JSON l_json ERROR_VARIABLE l_err
        SET "${l_json}" "${dep_name}" "sha256" "\"${sha256}\"")
    string(JSON l_json ERROR_VARIABLE l_err
        SET "${l_json}" "${dep_name}" "url" "\"${url}\"")
    file(WRITE "${CMAKE_SOURCE_DIR}/nest.lock" "${l_json}\n")
    message(STATUS "[nest] · Lockfile updated: nest.lock")
endfunction()

# Root folder name used as namespace / project prefix
get_filename_component(nest_TOPNAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
string(TOUPPER "${nest_TOPNAME}" _g_nest_TOPNAME_UPPER)



# PUBLIC API — nest_
################################################################################

macro(nest_INIT cxx_standard)
    message("")

    include(GNUInstallDirs)

    option(${_g_nest_TOPNAME_UPPER}_INSTALL_BINARY_ALL "Install all binary targets" ON)
    option(NEST_ASAN "Enable ASan" OFF)
    option(NEST_UBSAN "Enable UBSan" OFF)
    option(NEST_WERRORS "Treat compiler warnings as errors" OFF)

    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type")

    set(_g_nest_CXX_STANDARD ${cxx_standard})
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    find_program(_l_nest_CCACHE ccache)
    if(_l_nest_CCACHE)
        message(STATUS "[nest] · Build Cache: ccache enabled")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${_l_nest_CCACHE}")
        set(CMAKE_C_COMPILER_LAUNCHER "${_l_nest_CCACHE}")
    else()
        message(STATUS "[nest] · Build Cache: ccache not found")
    endif()

    # --- Lockfile: one-shot update flag ---
    if(DEFINED UPDATE_NEST_LOCK)
        file(REMOVE "${CMAKE_SOURCE_DIR}/nest.lock")
        file(REMOVE_RECURSE "${FETCHCONTENT_BASE_DIR}")
        unset(UPDATE_NEST_LOCK CACHE)
        message(STATUS "[nest] · Regenerating lockfile (UPDATE_NEST_LOCK)")
    endif()

    message("")
endmacro()


macro(nest_VERSION major minor patch)
    set(NEST_VERSION "${major}.${minor}.${patch}")
endmacro()


macro(nest_SETUP_EXE)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    _nest_ADD_TARGET(${PROJECT_NAME} ${PROJECT_SOURCE_DIR} "EXE")
    _nest_SET_OUTPUT_DIR(${PROJECT_NAME} "bin/${PROJECT_NAME}")

    _m_nest_APPLY_STANDARD_PROPS(${PROJECT_NAME})

    option(${_g_nest_TOPNAME_UPPER}_INSTALL_BINARY_${PROJECT_NAME}
        "Install ${PROJECT_NAME} binary" ON)
    if(${_g_nest_TOPNAME_UPPER}_INSTALL_BINARY_ALL
        AND ${_g_nest_TOPNAME_UPPER}_INSTALL_BINARY_${PROJECT_NAME})
        install(TARGETS ${PROJECT_NAME}
            EXPORT ${nest_TOPNAME}-targets
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    endif()
endmacro()


macro(nest_SETUP_LIB lib_type)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    _nest_ADD_TARGET(${PROJECT_NAME} ${PROJECT_SOURCE_DIR} ${lib_type})
    add_library(${nest_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
    _nest_SET_OUTPUT_DIR(${PROJECT_NAME} "lib/${PROJECT_NAME}")

    _m_nest_APPLY_STANDARD_PROPS(${PROJECT_NAME})

    if("${lib_type}" STREQUAL "SHARED")
        include(GenerateExportHeader)
        string(TOUPPER "${PROJECT_NAME}" _l_nest_PROJECT_UPPER)
        generate_export_header(${PROJECT_NAME}
            EXPORT_MACRO_NAME "${_l_nest_PROJECT_UPPER}_API"
        )
        target_include_directories(${PROJECT_NAME} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)
    endif()

    _nest_GLOB(${CMAKE_CURRENT_SOURCE_DIR} _l_nest_SOURCES _l_nest_HEADERS)
    install(TARGETS ${PROJECT_NAME}
        EXPORT ${nest_TOPNAME}-targets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(FILES ${_l_nest_HEADERS}
        DESTINATION include/${nest_TOPNAME}/${PROJECT_NAME})
    if("${lib_type}" STREQUAL "SHARED")
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}_export.h"
            DESTINATION include/${nest_TOPNAME}/${PROJECT_NAME})
    endif()
endmacro()


macro(nest_SETUP_HEADER_LIB)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})
    _nest_SETUP_HEADER_LIB_IMPL()
endmacro()

function(_nest_SETUP_HEADER_LIB_IMPL)
    message(STATUS "[nest] · HeaderLib: ${PROJECT_NAME}")

    add_library(${PROJECT_NAME} INTERFACE)
    add_library(${nest_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    target_include_directories(${PROJECT_NAME} INTERFACE
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include/${nest_TOPNAME}/${PROJECT_NAME}>
        $<INSTALL_INTERFACE:include/${nest_TOPNAME}/_private>)

    _nest_GLOB(${PROJECT_SOURCE_DIR} l_sources l_headers)
    if(l_headers)
        target_sources(${PROJECT_NAME} INTERFACE ${l_headers})
    endif()

    if(l_headers)
        install(FILES ${l_headers}
            DESTINATION include/${nest_TOPNAME}/${PROJECT_NAME})
    endif()
    install(TARGETS ${PROJECT_NAME}
        EXPORT ${nest_TOPNAME}-targets)
endfunction()



function(nest_DEP lib_name lib_version lib_url)
    string(TOUPPER "${lib_name}" l_dep_upper)

    if(NOT lib_url MATCHES "refs/tags/")
        message(WARNING "[nest] · ${lib_name}: URL does not point to a tag. "
            "Prefer refs/tags/ for reproducible deps.")
    endif()

    # --- Version conflict detection ---
    list(FIND _g_nest_DEP_NAMES "${lib_name}" _l_dep_idx)
    if(_l_dep_idx GREATER -1)
        list(GET _g_nest_DEP_VERSIONS ${_l_dep_idx} _l_existing_ver)
        if(NOT _l_existing_ver STREQUAL "${lib_version}")
            list(GET _g_nest_DEP_PROJECTS ${_l_dep_idx} _l_existing_proj)
            message(WARNING "[nest] · VERSION CONFLICT: ${lib_name}"
                " requested v${lib_version} (from ${PROJECT_NAME})"
                " but already declared as v${_l_existing_ver} (from ${_l_existing_proj})")
        endif()
    else()
        list(APPEND _g_nest_DEP_NAMES "${lib_name}")
        list(APPEND _g_nest_DEP_VERSIONS "${lib_version}")
        list(APPEND _g_nest_DEP_PROJECTS "${PROJECT_NAME}")
    endif()

    option(${_g_nest_TOPNAME_UPPER}_USE_SYSTEM_${l_dep_upper}
        "Use system ${lib_name} (skip FetchContent)" OFF)

    if(${_g_nest_TOPNAME_UPPER}_USE_SYSTEM_${l_dep_upper})
        _nest_DEP_IMPL("${lib_name}" "${lib_version}" "${lib_url}" TRUE)
    else()
        _nest_DEP_IMPL("${lib_name}" "${lib_version}" "${lib_url}" FALSE)
    endif()
endfunction()


function(_nest_DEP_IMPL lib_name lib_version lib_url sys_first)
    if(sys_first)
        find_package(${lib_name} ${lib_version} QUIET)
    endif()

    if(NOT ${lib_name}_FOUND)
        message(STATUS "[nest] · External: ${lib_name} ${lib_version}")

        # --- Lockfile: check existing entry ---
        _nest_LOCKFILE_GET("${lib_name}" "sha256" l_hash)
        _nest_LOCKFILE_GET("${lib_name}" "url" l_locked_url)

        # If URL changed, invalidate hash
        if(l_locked_url AND NOT l_locked_url STREQUAL lib_url)
            message(STATUS "[nest] · ···· URL changed for ${lib_name}, re-fetching")
            set(l_hash "")
        endif()

        if(l_hash)
            # Hash known — pass URL_HASH for verification
            message(STATUS "[nest] · ···· Locked: sha256=${l_hash}")
            FetchContent_Declare(${lib_name}
                DOWNLOAD_EXTRACT_TIMESTAMP OFF
                URL ${lib_url}
                URL_HASH SHA256=${l_hash}
            )
            FetchContent_MakeAvailable(${lib_name})
        else()
            # No hash yet — download, compute, save to lockfile
            set(l_cache_dir "${FETCHCONTENT_BASE_DIR}/__lockcache__")
            file(MAKE_DIRECTORY "${l_cache_dir}")
            get_filename_component(l_archive_name "${lib_url}" NAME)
            if(NOT l_archive_name)
                set(l_archive_name "${lib_name}.zip")
            endif()
            set(l_archive_path "${l_cache_dir}/${l_archive_name}")

            message(STATUS "[nest] · ···· Downloading to compute hash")
            file(DOWNLOAD ${lib_url} "${l_archive_path}"
                SHOW_PROGRESS STATUS l_dl_status LOG l_dl_log)

            list(GET l_dl_status 0 l_dl_code)
            if(NOT l_dl_code EQUAL 0)
                list(GET l_dl_status 1 l_dl_msg)
                message(FATAL_ERROR "[nest] · ···· ···· Failed to download ${lib_name}: ${l_dl_msg}")
            endif()

            file(SHA256 "${l_archive_path}" l_hash)
            string(SUBSTRING "${l_hash}" 0 16 l_hash_short)
            message(STATUS "[nest] · ···· SHA256: ${l_hash_short}")

            _nest_LOCKFILE_SET("${lib_name}" "${lib_version}" "${l_hash}" "${lib_url}")

            FetchContent_Declare(${lib_name}
                DOWNLOAD_EXTRACT_TIMESTAMP OFF
                URL "${l_archive_path}"
                URL_HASH SHA256=${l_hash}
            )
            FetchContent_MakeAvailable(${lib_name})
        endif()

        _nest_TRY_ADD_CONFIG(${lib_name})
    else()
        message(STATUS "[nest] · System: ${lib_name}")
        _nest_ADD_TO_EXTERNAL_CONFIG(${lib_name})
    endif()

    _nest_ADD_TO_EXTERNAL(${lib_name})

    message("")
endfunction()


function(nest_DETECT_PROJECTS)
    set(l_found_dirs "")
    set(l_root_dir ${CMAKE_CURRENT_SOURCE_DIR})
    set(l_projects_dir "${l_root_dir}/projects")

    if(NOT EXISTS "${l_projects_dir}")
        return()
    endif()

    file(GLOB l_root_content LIST_DIRECTORIES TRUE CONFIGURE_DEPENDS RELATIVE "${l_projects_dir}" "${l_projects_dir}/*")

    foreach(l_item ${l_root_content})
        set(l_item_dir "${l_projects_dir}/${l_item}")
        _nest_HAS_CMAKEFILE("${l_item_dir}" l_has_cmakefile)

        if(${l_has_cmakefile})
            string(SUBSTRING "${l_item}" 0 1 l_first_char)
            if(NOT (l_first_char STREQUAL "."))
                list(APPEND l_found_dirs "${l_item}")
            endif()
        endif()
    endforeach()

    foreach(l_dir ${l_found_dirs})
        add_subdirectory("projects/${l_dir}")
    endforeach()
endfunction()


macro(nest_ENABLE_TESTS)
    if(PROJECT_IS_TOP_LEVEL)
        enable_testing()
        _nest_ENABLE_TESTS_IMPL()
    endif()
endmacro()

function(_nest_ENABLE_TESTS_IMPL)
    message(STATUS "[nest] · Enabling tests")

    _nest_GLOB("${CMAKE_SOURCE_DIR}/tests" l_sources l_headers)

    foreach(l_source IN LISTS l_sources)
        get_filename_component(l_name "${l_source}" NAME_WE)

        add_executable(${l_name} "${l_source}")

        _nest_SETUP_TARGET_FLAGS(${l_name})
        if(_g_nest_EXTERNAL)
            target_link_libraries(${l_name} PRIVATE ${_g_nest_EXTERNAL})
        endif()

        target_include_directories(${l_name} PRIVATE "${CMAKE_SOURCE_DIR}/vendor")

        set_target_properties(${l_name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/.nest/tests")

        add_test(NAME "${l_name}" COMMAND "${l_name}")

        message(STATUS "[nest] · Test: ${l_name} -- ${l_source}")
    endforeach()

    message("")
endfunction()


function(nest_LINK_PROJECTS)
    if(ARGN)
        message(STATUS "[nest] · ···· Linking to: ${ARGN}")
        target_link_libraries(${PROJECT_NAME} PRIVATE ${ARGN})
    endif()
endfunction()


function(nest_GENERATE_EXPORT)
    include(CMakePackageConfigHelpers)

    install(EXPORT ${nest_TOPNAME}-targets
        FILE ${nest_TOPNAME}-targets.cmake
        NAMESPACE ${nest_TOPNAME}::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${nest_TOPNAME})

    set(NEST_CONFIG_FIND_DEPS "")
    foreach(l_dep IN LISTS _g_nest_EXTERNAL_CONFIG)
        string(APPEND NEST_CONFIG_FIND_DEPS "find_dependency(${l_dep})\n")
    endforeach()

    configure_package_config_file(
        ${CMAKE_SOURCE_DIR}/cmake/${nest_TOPNAME}Config.cmake.in
        ${CMAKE_BINARY_DIR}/${nest_TOPNAME}Config.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${nest_TOPNAME})

    install(FILES ${CMAKE_BINARY_DIR}/${nest_TOPNAME}Config.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${nest_TOPNAME})

    if(NEST_VERSION)
        write_basic_package_version_file(
            ${CMAKE_BINARY_DIR}/${nest_TOPNAME}ConfigVersion.cmake
            VERSION ${NEST_VERSION}
            COMPATIBILITY AnyNewerVersion)
        install(FILES ${CMAKE_BINARY_DIR}/${nest_TOPNAME}ConfigVersion.cmake
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${nest_TOPNAME})
    endif()

    install(DIRECTORY ${CMAKE_SOURCE_DIR}/vendor/
        DESTINATION include/${nest_TOPNAME}/_private)
endfunction()



# INTERNAL FUNCTIONS — _nest_
################################################################################

function(_nest_ADD_TO_EXTERNAL lib_name)
    set(l_tmp ${_g_nest_EXTERNAL})
    list(APPEND l_tmp ${lib_name})
    list(REMOVE_DUPLICATES l_tmp)
    set(_g_nest_EXTERNAL "${l_tmp}" CACHE INTERNAL "Global external dependencies list")
endfunction()


function(_nest_ADD_TO_EXTERNAL_CONFIG lib_name)
    set(l_tmp ${_g_nest_EXTERNAL_CONFIG})
    list(APPEND l_tmp ${lib_name})
    list(REMOVE_DUPLICATES l_tmp)
    set(_g_nest_EXTERNAL_CONFIG "${l_tmp}" CACHE INTERNAL "External deps needing find_dependency")
endfunction()


function(_nest_TRY_ADD_CONFIG lib_name)
    FetchContent_GetProperties(${lib_name} BINARY_DIR l_bin)
    if(NOT "${l_bin}" STREQUAL ""
       AND (EXISTS "${l_bin}/${lib_name}Config.cmake"
            OR EXISTS "${l_bin}/${lib_name}-config.cmake"))
        _nest_ADD_TO_EXTERNAL_CONFIG(${lib_name})
    endif()
endfunction()


function(_nest_GLOB root_dir out_sources out_headers)
    file(GLOB l_sources CONFIGURE_DEPENDS "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c")
    set(${out_sources} "${l_sources}" PARENT_SCOPE)

    file(GLOB l_headers CONFIGURE_DEPENDS "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h")
    set(${out_headers} "${l_headers}" PARENT_SCOPE)
endfunction()


function(nest_LINK)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${ARGN})
endfunction()


function(_nest_SETUP_TARGET_FLAGS proj_name)
    target_compile_features(${proj_name} PRIVATE cxx_std_${_g_nest_CXX_STANDARD})
    set_target_properties(${proj_name} PROPERTIES
        CXX_EXTENSIONS OFF
        CXX_STANDARD_REQUIRED ON
    )

    if(MSVC)
        target_compile_options(${proj_name} PRIVATE /W4)
    else()
        target_compile_options(${proj_name} PRIVATE -Wall -Wextra -Wpedantic)
    endif()

    if(NEST_WERRORS)
        set_target_properties(${proj_name} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
    endif()

    if(NEST_ASAN)
        _nest_ENABLE_SANITIZER(${proj_name} "address")
    endif()

    if(NEST_UBSAN)
        _nest_ENABLE_SANITIZER(${proj_name} "undefined")
    endif()
endfunction()


function(_nest_ENABLE_SANITIZER proj_name sanitizer)
    if(MSVC)
        target_compile_options(${proj_name} PRIVATE /fsanitize=${sanitizer})
    else()
        target_compile_options(${proj_name} PRIVATE -fsanitize=${sanitizer})
        target_link_options(${proj_name} PRIVATE -fsanitize=${sanitizer})
    endif()
endfunction()


function(_nest_SET_OUTPUT_DIR proj_name dir_name)
    if(NOT NEST_VERSION)
        set(NEST_VERSION "0.0.0")
    endif()
    set(l_output_dir "${CMAKE_SOURCE_DIR}/.nest/${dir_name}/v${NEST_VERSION}/$<CONFIG>")
    message(DEBUG "[nest] · OutputDir -> ${l_output_dir}")

    set_target_properties(${proj_name} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${l_output_dir}"
        LIBRARY_OUTPUT_DIRECTORY "${l_output_dir}"
        RUNTIME_OUTPUT_DIRECTORY "${l_output_dir}"
    )
endfunction()


function(_nest_HAS_CMAKEFILE root_dir out_has_cmakefile)
    if(EXISTS "${root_dir}/CMakeLists.txt")
        set(${out_has_cmakefile} ON PARENT_SCOPE)
    else()
        set(${out_has_cmakefile} OFF PARENT_SCOPE)
    endif()
endfunction()


function(_nest_ADD_TARGET proj_name proj_root_dir target_type)
    _nest_GLOB(${proj_root_dir} l_sources l_headers)
    if("${target_type}" STREQUAL "EXE")
        message(STATUS "[nest] · Project: ${proj_name}")
        add_executable(${proj_name} ${l_sources} ${l_headers})
    else()
        message(STATUS "[nest] · Library: ${proj_name} (${target_type})")
        add_library(${proj_name} ${target_type} ${l_sources} ${l_headers})
    endif()
endfunction()



# INTERNAL MACROS — _m_nest_
################################################################################

macro(_m_nest_INIT_TARGET_SCOPE)
    get_filename_component(_l_nest_NAME_AUX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" _l_nest_NAME "${_l_nest_NAME_AUX}")
    project(${_l_nest_NAME})
endmacro()


macro(_m_nest_APPLY_STANDARD_PROPS target_name)
    set_target_properties(${target_name} PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
        EXPORT_COMPILE_COMMANDS ON
    )

    get_target_property(_l_nest_TYPE ${target_name} TYPE)
    if("${_l_nest_TYPE}" STREQUAL "EXECUTABLE")
        target_include_directories(${target_name} PRIVATE
            ${PROJECT_SOURCE_DIR}
            ${CMAKE_SOURCE_DIR}/vendor)
    else()
        target_include_directories(${target_name} PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>
            $<INSTALL_INTERFACE:include/${nest_TOPNAME}>
            $<INSTALL_INTERFACE:include/${nest_TOPNAME}/_private>)
        target_include_directories(${target_name} PRIVATE
            $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
    endif()

    _nest_SETUP_TARGET_FLAGS(${target_name})
endmacro()


#
## SCRIPT MODE — s_nest_
################################################################################

function(s_nest_SCAFFOLD target_name target_type)
    get_filename_component(l_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
    set(l_target_dir "${l_root}/projects/${target_name}")

    if(EXISTS "${l_target_dir}")
        message(FATAL_ERROR "🔴 Directory '${target_name}' already exists.")
    endif()

    file(MAKE_DIRECTORY "${l_target_dir}")

    if(target_type STREQUAL "EXE")
        file(WRITE "${l_target_dir}/CMakeLists.txt" "nest_VERSION(0 0 1)\nnest_SETUP_EXE()\n# nest_LINK(foo bar)\n")
        file(WRITE "${l_target_dir}/main.cpp" "#include <cstdio>\n\nint main() {\n    std::puts(\"Hello from ${target_name}!\");\n}\n")
        message(STATUS "✅ Created executable project '${target_name}'")
    else()
        file(WRITE "${l_target_dir}/CMakeLists.txt" "nest_VERSION(0 0 1)\nnest_SETUP_LIB(${target_type})\n# nest_LINK(foo bar)\n")
        file(WRITE "${l_target_dir}/${target_name}.hpp" "#pragma once\n")
        if(target_type STREQUAL "SHARED")
            file(APPEND "${l_target_dir}/${target_name}.hpp" "#include \"${target_name}_export.h\"\n")
        endif()

        file(WRITE "${l_target_dir}/${target_name}.cpp" "#include \"${target_name}.hpp\"\n")
        message(STATUS "✅ Created ${target_type} library project '${target_name}'")
    endif()
endfunction()


if(CMAKE_SCRIPT_MODE_FILE)

    if(NEST_DO_SCAFFOLD)
        s_nest_SCAFFOLD("${TARGET_NAME}" "${TARGET_TYPE}")
    endif()

endif()
