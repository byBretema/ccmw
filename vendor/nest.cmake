
#
## GLOBAL STATEE
################################################################################

include(FetchContent)

set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/build/deps")

# Gets track of all external dependencies added via nest_ADD_DEP, to link them easily later
set(__nest_DEPS "" CACHE INTERNAL "Global external dependencies list")

# Gets the name of the root folder (e.g., "MyNest")
# to use as namespace / project_name
get_filename_component(nest_TOPNAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)


#
## API
################################################################################

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

macro(nest_INIT cxx_standard)
    option(NEST_ASAN "Enable AddressSanitizer (ASan) for memory leak detection" OFF)
    option(NEST_WERRORS "Treat compiler warnings as errors" OFF)

    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Debug)
    endif()

    set(CMAKE_CXX_STANDARD ${cxx_standard})
    set(CMAKE_CXX_EXTENSIONS OFF)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    # Force compile_commands.json generation globally!
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "[nest] · Build Cache : ccache enabled")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
        set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    else()
        message(STATUS "[nest] · Build Cache : ccache not found")
    endif()
    message("")
endmacro()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# function(nest_LOAD_DEPENDENCIES)
#     set(l_PRESETS_FILE "${CMAKE_CURRENT_SOURCE_DIR}/CMakePresets.json")

#     if(NOT EXISTS "${l_PRESETS_FILE}")
#         message(WARNING "[nest] · No CMakePresets.json found. Skipping dependencies.")
#         return()
#     endif()

#     file(READ "${l_PRESETS_FILE}" l_JSON_STR)

#     string(JSON l_DEP_COUNT ERROR_VARIABLE l_JSON_ERR LENGTH "${l_JSON_STR}" "vendor" "__nest_deps")

#     if(l_JSON_ERR OR l_DEP_COUNT EQUAL 0)
#         message(DEBUG "[nest] · No dependencies found in CMakePresets.json.")
#         return()
#     endif()

#     message(STATUS "[nest] · Parsing dependencies from CMakePresets.json...")

#     math(EXPR l_LAST_INDEX "${l_DEP_COUNT} - 1")

#     foreach(l_INDEX RANGE ${l_LAST_INDEX})
#         string(JSON l_NAME GET "${l_JSON_STR}" "vendor" "__nest_deps" ${l_INDEX} "name")
#         string(JSON l_VER GET "${l_JSON_STR}" "vendor" "__nest_deps" ${l_INDEX} "version")
#         string(JSON l_SYS GET "${l_JSON_STR}" "vendor" "__nest_deps" ${l_INDEX} "sys_first")
#         string(JSON l_URL GET "${l_JSON_STR}" "vendor" "__nest_deps" ${l_INDEX} "url")

#         nest_ADD_DEP("${l_NAME}" "${l_VER}" "${l_URL}" "${l_SYS}")
#     endforeach()
# endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_DETECT_PROJECTS)
    set(l_FOUND_DIRS "")
    set(l_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

    file(GLOB l_ROOT_CONTENT LIST_DIRECTORIES TRUE RELATIVE "${l_ROOT_DIR}" "${l_ROOT_DIR}/*")

    foreach(l_ITEM ${l_ROOT_CONTENT})
        set(l_ITEM_DIR "${l_ROOT_DIR}/${l_ITEM}")
        _nest_HAS_CMAKEFILE("${l_ITEM_DIR}" l_HAS_CMAKEFILE)

        if(${l_HAS_CMAKEFILE})
            string(SUBSTRING "${l_ITEM}" 0 1 l_FIRST_CHAR)
            if(NOT (l_FIRST_CHAR STREQUAL "."))
                list(APPEND l_FOUND_DIRS "${l_ITEM}")
            endif()
        endif()
    endforeach()

    foreach(l_DIR ${l_FOUND_DIRS})
        add_subdirectory("${l_DIR}")
        message("")
    endforeach()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_ENABLE_TESTS)
    message(STATUS "[nest] · Enabling tests")

    enable_testing()
    _nest_GLOB("${CMAKE_SOURCE_DIR}/tests" _sources _headers)

    foreach(_source IN LISTS _sources)
        get_filename_component(_name "${_source}" NAME_WE)

        add_executable(${_name} "${_source}")

        _nest_SET_OUTPUT_DIR(${_name} "tests")
        _nest_ENABLE_STRICT_MODE(${_name})
        _nest_LINK_DEPS(${_name})

        add_test(NAME "${_name}" COMMAND "${_name}")

        message(STATUS "[nest] · Test     : ${_name} -- ${_source}")
    endforeach()

    message("")
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_ADD_DEP lib_name lib_version lib_url sys_first)
    if(${sys_first})
        find_package(${lib_name} ${lib_version} QUIET)
    endif()

    if(NOT ${lib_name}_FOUND)
        message(STATUS "[nest] · External : ${lib_name}")
        FetchContent_Declare(${lib_name} DOWNLOAD_EXTRACT_TIMESTAMP OFF URL ${lib_url})
        FetchContent_MakeAvailable(${lib_name})
    else()
        message(STATUS "[nest] · System   : ${lib_name}")
    endif()

    # Safely append to the global list using native CMake lists
    set(l_TMP ${__nest_DEPS})
    list(APPEND l_TMP ${lib_name})
    list(REMOVE_DUPLICATES l_TMP)
    set(__nest_DEPS "${l_TMP}" CACHE INTERNAL "Global external dependencies list")

    message("")
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_SETUP_EXE)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    _nest_ADD_EXE(${PROJECT_NAME} ${PROJECT_SOURCE_DIR})
    _nest_SET_OUTPUT_DIR(${PROJECT_NAME} "bin/${PROJECT_NAME}")

    _m_nest_APPLY_STANDARD_PROPS(${PROJECT_NAME})
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_SETUP_LIB lib_type)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    _nest_ADD_LIB(${PROJECT_NAME} ${PROJECT_SOURCE_DIR} ${lib_type})
    add_library(${nest_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
    _nest_SET_OUTPUT_DIR(${PROJECT_NAME} "lib/${PROJECT_NAME}")

    _m_nest_APPLY_STANDARD_PROPS(${PROJECT_NAME})
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_SETUP_HEADER_LIB)
    _m_nest_INIT_TARGET_SCOPE(${ARGN})

    message(STATUS "[nest] · HeaderLib: ${PROJECT_NAME}")

    add_library(${PROJECT_NAME} INTERFACE)
    add_library(${nest_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    target_include_directories(${PROJECT_NAME} INTERFACE ${PROJECT_SOURCE_DIR})

    _nest_GLOB(${PROJECT_SOURCE_DIR} l_SOURCES l_HEADERS)
    if(l_HEADERS)
        target_sources(${PROJECT_NAME} INTERFACE ${l_HEADERS})
    endif()

    if(l_DO_LINK AND __nest_DEPS)
        target_link_libraries(${PROJECT_NAME} INTERFACE ${__nest_DEPS})
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(nest_LINK_INTERNAL)
    if(ARGN)
        message(STATUS "[nest] · Internal : ${PROJECT_NAME} linking to [${ARGN}]")
        target_link_libraries(${PROJECT_NAME} PRIVATE ${ARGN})
        target_include_directories(${PROJECT_NAME} PUBLIC ${ARGN})
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


#
## DETAILS - Funcs
################################################################################

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_GLOB root_dir out_sources out_headers)
    file(GLOB l_SOURCES "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c")
    set(${out_sources} "${l_SOURCES}" PARENT_SCOPE)

    file(GLOB l_HEADERS "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h")
    set(${out_headers} "${l_HEADERS}" PARENT_SCOPE)
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_LINK_DEPS proj_name)
    if(__nest_DEPS)
        target_link_libraries(${proj_name} PRIVATE ${__nest_DEPS})
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_ENABLE_STRICT_MODE proj_name)
    # Enable warnings
    if(MSVC)
        target_compile_options(${proj_name} PRIVATE /W4)
    else()
        target_compile_options(${proj_name} PRIVATE -Wall -Wextra -Wpedantic)
    endif()

    # Warnings as errors
    if(NEST_WERRORS)
        set_target_properties(${proj_name} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
    endif()

    # Enable ASan
    if(NEST_ASAN)
        message(DEBUG "[nest] · Enabling ASan for ${proj_name}")
        if(MSVC)
            target_compile_options(${proj_name} PRIVATE /fsanitize=address)
        else()
            target_compile_options(${proj_name} PRIVATE -fsanitize=address)
            target_link_options(${proj_name} PRIVATE -fsanitize=address)
        endif()
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_SET_OUTPUT_DIR proj_name dir_name)
    set(l_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../${dir_name}")
    message(DEBUG "[nest] · OutputDir -> ${l_OUTPUT_DIR}")

    set_target_properties(${proj_name} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        LIBRARY_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
    )
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_HAS_CMAKEFILE root_dir out_has_cmakefile)
    file(GLOB l_CMAKEFILE "${root_dir}/CMakeLists.txt")
    if(l_CMAKEFILE)
        set(${out_has_cmakefile} ON PARENT_SCOPE)
    else()
        set(${out_has_cmakefile} OFF PARENT_SCOPE)
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_ADD_EXE proj_name proj_root_dir)
    _nest_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)
    message(STATUS "[nest] · Project  : ${proj_name}")
    add_executable(${proj_name} ${l_SOURCES} ${l_HEADERS})
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(_nest_ADD_LIB proj_name proj_root_dir lib_type)
    _nest_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)
    message(STATUS "[nest] · Library  : ${proj_name} (${lib_type})")
    add_library(${proj_name} ${lib_type} ${l_SOURCES} ${l_HEADERS})
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


#
## DETAILS - Macros
################################################################################

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

macro(_m_nest_INIT_TARGET_SCOPE)
    set(a_LINK_DEPS ${ARGN})
    if(a_LINK_DEPS)
        list(POP_FRONT a_LINK_DEPS l_DO_LINK)
    else()
        set(l_DO_LINK FALSE)
    endif()

    get_filename_component(l_NAME_AUX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" l_NAME "${l_NAME_AUX}")
    project(${l_NAME})
endmacro()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

macro(_m_nest_APPLY_STANDARD_PROPS target_name)
    set_target_properties(${target_name} PROPERTIES
        CXX_EXTENSIONS OFF
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
        EXPORT_COMPILE_COMMANDS ON
    )

    target_include_directories(${target_name} PUBLIC ${PROJECT_SOURCE_DIR})
    _nest_ENABLE_STRICT_MODE(${target_name})

    if(l_DO_LINK)
        _nest_LINK_DEPS(${target_name})
    endif()
endmacro()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


#
## SCRIPT MODE - Functions
################################################################################

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function(s_nest_SCAFFOLD target_name target_type)
    # Find the repository root (one level up from the .nest folder)
    get_filename_component(l_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
    set(l_TARGET_DIR "${l_ROOT}/${target_name}")

    if(EXISTS "${l_TARGET_DIR}")
        message(FATAL_ERROR "🔴 Directory '${target_name}' already exists.")
    endif()

    file(MAKE_DIRECTORY "${l_TARGET_DIR}")

    if(target_type STREQUAL "EXE")
        file(WRITE "${l_TARGET_DIR}/CMakeLists.txt" "nest_SETUP_EXE()\n")
        file(WRITE "${l_TARGET_DIR}/main.cpp"
"#include <iostream>\n\nint main() {\n    std::cout << \"Hello from ${target_name}!\\n\";\n    return 0;\n}\n")
        message(STATUS "✅ Created executable project '${target_name}'")
    else()
        file(WRITE "${l_TARGET_DIR}/CMakeLists.txt" "nest_SETUP_LIB(${target_type})\n")
        file(WRITE "${l_TARGET_DIR}/${target_name}.hpp"
"#pragma once\n\nvoid hello_${target_name}();\n")
        file(WRITE "${l_TARGET_DIR}/${target_name}.cpp"
"#include \"${target_name}.hpp\"\n#include <iostream>\n\nvoid hello_${target_name}() {\n    std::cout << \"Hello from the ${target_name} library!\\n\";\n}\n")
        message(STATUS "✅ Created ${target_type} library project '${target_name}'")
    endif()
endfunction()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


#
## SCRIPT MODE - Entry Point
################################################################################

if(CMAKE_SCRIPT_MODE_FILE)

    if(NEST_DO_SCAFFOLD)
        s_nest_SCAFFOLD("${TARGET_NAME}" "${TARGET_TYPE}")
    endif()

endif()
