
# GLOBAL STATE
################################################################################

include(FetchContent)

set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/.nest/vendor")

# Tracks all external deps added via nest_FETCH_DEP / nest_SYS_DEP / etc.
set(_g_nest_EXTERNAL "" CACHE INTERNAL "Global external-dependencies list")

# Root folder name used as namespace / project prefix
get_filename_component(nest_TOPNAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)



# PUBLIC API — nest_
################################################################################

macro(nest_INIT cxx_standard)
    message("")

    option(NEST_ASAN "Enable ASan" OFF)
    option(NEST_UBSAN "Enable UBSan" OFF)
    option(NEST_WERRORS "Treat compiler warnings as errors" OFF)

    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Debug)
    endif()

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
            EXPORT_FILE_NAME  "${CMAKE_CURRENT_SOURCE_DIR}/export.h"
        )
        target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
    endif()
endmacro()


macro(nest_SETUP_HEADER_LIB)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    message(STATUS "[nest] · HeaderLib: ${PROJECT_NAME}")

    add_library(${PROJECT_NAME} INTERFACE)
    add_library(${nest_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    target_include_directories(${PROJECT_NAME} INTERFACE ${PROJECT_SOURCE_DIR})

    _nest_GLOB(${PROJECT_SOURCE_DIR} l_SOURCES l_HEADERS)
    if(l_HEADERS)
        target_sources(${PROJECT_NAME} INTERFACE ${l_HEADERS})
    endif()

    if(_l_nest_DO_LINK)
        _nest_LINK_EXTERNAL(${PROJECT_NAME} "INTERFACE")
    endif()
endmacro()


function(nest_FETCH_DEP lib_name lib_version lib_url)
    nest_ADD_DEP("${lib_name}" "${lib_version}" "${lib_url}" FALSE)
endfunction()


function(nest_SYS_FIRST_DEP lib_name lib_version lib_url)
    nest_ADD_DEP("${lib_name}" "${lib_version}" "${lib_url}" TRUE)
endfunction()


function(nest_SYS_DEP lib_name lib_version)
    find_package(${lib_name} ${lib_version} REQUIRED)
    _nest_ADD_TO_EXTERNAL(${lib_name})
    message(STATUS "[nest] · System: ${lib_name}")
    message("")
endfunction()


function(nest_ADD_DEP lib_name lib_version lib_url sys_first)
    if(sys_first)
        find_package(${lib_name} ${lib_version} QUIET)
    endif()

    if(NOT ${lib_name}_FOUND)
        message(STATUS "[nest] · External: ${lib_name}")
        FetchContent_Declare(${lib_name} DOWNLOAD_EXTRACT_TIMESTAMP OFF URL ${lib_url})
        FetchContent_MakeAvailable(${lib_name})
    else()
        message(STATUS "[nest] · System: ${lib_name}")
    endif()

    _nest_ADD_TO_EXTERNAL(${lib_name})

    message("")
endfunction()


function(nest_DETECT_PROJECTS)
    set(l_FOUND_DIRS "")
    set(l_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    set(l_PROJECTS_DIR "${l_ROOT_DIR}/projects")

    if(NOT EXISTS "${l_PROJECTS_DIR}")
        return()
    endif()

    file(GLOB l_ROOT_CONTENT LIST_DIRECTORIES TRUE RELATIVE "${l_PROJECTS_DIR}" "${l_PROJECTS_DIR}/*")

    foreach(l_ITEM ${l_ROOT_CONTENT})
        set(l_ITEM_DIR "${l_PROJECTS_DIR}/${l_ITEM}")
        _nest_HAS_CMAKEFILE("${l_ITEM_DIR}" l_HAS_CMAKEFILE)

        if(${l_HAS_CMAKEFILE})
            string(SUBSTRING "${l_ITEM}" 0 1 l_FIRST_CHAR)
            if(NOT (l_FIRST_CHAR STREQUAL "."))
                list(APPEND l_FOUND_DIRS "${l_ITEM}")
            endif()
        endif()
    endforeach()

    foreach(l_DIR ${l_FOUND_DIRS})
        add_subdirectory("projects/${l_DIR}")
    endforeach()
endfunction()


function(nest_ENABLE_TESTS)
    if(NOT PROJECT_IS_TOP_LEVEL)
        return()
    endif()

    enable_testing()
    message(STATUS "[nest] · Enabling tests")

    _nest_GLOB("${CMAKE_SOURCE_DIR}/tests" l_sources l_headers)

    foreach(l_source IN LISTS l_sources)
        get_filename_component(l_name "${l_source}" NAME_WE)

        add_executable(${l_name} "${l_source}")

        _nest_SETUP_TARGET_FLAGS(${l_name})
        _nest_LINK_EXTERNAL(${l_name})

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



# INTERNAL FUNCTIONS — _nest_
################################################################################

function(_nest_ADD_TO_EXTERNAL lib_name)
    set(l_TMP ${_g_nest_EXTERNAL})
    list(APPEND l_TMP ${lib_name})
    list(REMOVE_DUPLICATES l_TMP)
    set(_g_nest_EXTERNAL "${l_TMP}" CACHE INTERNAL "Global external dependencies list")
endfunction()


function(_nest_GLOB root_dir out_sources out_headers)
    file(GLOB l_SOURCES CONFIGURE_DEPENDS "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c")
    set(${out_sources} "${l_SOURCES}" PARENT_SCOPE)

    file(GLOB l_HEADERS CONFIGURE_DEPENDS "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h")
    set(${out_headers} "${l_HEADERS}" PARENT_SCOPE)
endfunction()


function(_nest_LINK_EXTERNAL proj_name)
    set(l_visibility "PRIVATE")
    if(ARGC GREATER 1)
        set(l_visibility "${ARGV1}")
    endif()
    if(_g_nest_EXTERNAL)
        target_link_libraries(${proj_name} ${l_visibility} ${_g_nest_EXTERNAL})
    endif()
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
    if(CMAKE_CONFIGURATION_TYPES)
        set(l_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/.nest/${dir_name}/v${NEST_VERSION}")
    else()
        set(l_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/.nest/${dir_name}/v${NEST_VERSION}/$<CONFIG>")
    endif()
    message(DEBUG "[nest] · OutputDir -> ${l_OUTPUT_DIR}")

    set_target_properties(${proj_name} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        LIBRARY_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
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
    _nest_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)
    if("${target_type}" STREQUAL "EXE")
        message(STATUS "[nest] · Project: ${proj_name}")
        add_executable(${proj_name} ${l_SOURCES} ${l_HEADERS})
    else()
        message(STATUS "[nest] · Library: ${proj_name} (${target_type})")
        add_library(${proj_name} ${target_type} ${l_SOURCES} ${l_HEADERS})
    endif()
endfunction()



# INTERNAL MACROS — _m_nest_
################################################################################

macro(_m_nest_INIT_TARGET_SCOPE)
    set(_l_nest_WANT_LINK ${ARGN})
    if(_l_nest_WANT_LINK)
        list(POP_FRONT _l_nest_WANT_LINK _l_nest_DO_LINK)
    else()
        set(_l_nest_DO_LINK FALSE)
    endif()

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

    target_include_directories(${target_name} PUBLIC
        ${PROJECT_SOURCE_DIR}
        ${CMAKE_SOURCE_DIR}/vendor
    )
    _nest_SETUP_TARGET_FLAGS(${target_name})

    if(_l_nest_DO_LINK)
        _nest_LINK_EXTERNAL(${target_name})
    endif()
endmacro()


#
## SCRIPT MODE — s_nest_
################################################################################

function(s_nest_SCAFFOLD target_name target_type)
    get_filename_component(l_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
    set(l_TARGET_DIR "${l_ROOT}/projects/${target_name}")

    if(EXISTS "${l_TARGET_DIR}")
        message(FATAL_ERROR "🔴 Directory '${target_name}' already exists.")
    endif()

    file(MAKE_DIRECTORY "${l_TARGET_DIR}")

    if(target_type STREQUAL "EXE")
        file(WRITE "${l_TARGET_DIR}/CMakeLists.txt" "nest_SETUP_EXE()\n")
        file(WRITE "${l_TARGET_DIR}/main.cpp" "#include <cstdio>\n\nint main() {\n    std::puts(\"Hello from ${target_name}!\");\n}\n")
        message(STATUS "✅ Created executable project '${target_name}'")
    else()
        file(WRITE "${l_TARGET_DIR}/CMakeLists.txt" "nest_SETUP_LIB(${target_type})\n")
        file(WRITE "${l_TARGET_DIR}/${target_name}.hpp" "#pragma once\n")
        if(target_type STREQUAL "SHARED")
            file(WRITE "${l_TARGET_DIR}/${target_name}.hpp" "#include \"export.h\"\n")
        endif()

        file(WRITE "${l_TARGET_DIR}/${target_name}.cpp" "#include \"${target_name}.hpp\"\n")
        message(STATUS "✅ Created ${target_type} library project '${target_name}'")
    endif()
endfunction()


if(CMAKE_SCRIPT_MODE_FILE)

    if(NEST_DO_SCAFFOLD)
        s_nest_SCAFFOLD("${TARGET_NAME}" "${TARGET_TYPE}")
    endif()

endif()
