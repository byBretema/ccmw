include(FetchContent)

# -----------------------------------------------------------------------------
# GLOBAL STATE
# -----------------------------------------------------------------------------
set(FETCHCONTENT_BASE_DIR ${CMAKE_SOURCE_DIR}/build/deps)
set(cm_DEPS "" CACHE INTERNAL "Global external dependencies list")

# Gets the name of the root folder (e.g., "MyMonorepo") to use as our namespace
get_filename_component(cm_TOPNAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)

# -----------------------------------------------------------------------------
# INITIALIZATION & CCACHE
# -----------------------------------------------------------------------------
macro(cm_INIT cxx_standard)
    # Define user-facing options (Default is OFF so local dev is easy)
    option(CM_ENABLE_ASAN "Enable AddressSanitizer (ASan) for memory leak detection" OFF)
    option(CM_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Debug)
    endif()

    set(CMAKE_CXX_STANDARD ${cxx_standard})
    set(CMAKE_CXX_EXTENSIONS OFF)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "[cm] · Build Cache : ccache enabled")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
        set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    endif()
    message("")
endmacro()

# -----------------------------------------------------------------------------
# STRICT MODE (WARNINGS & SANITIZERS)
# -----------------------------------------------------------------------------
function(cm_ENABLE_STRICT_MODE proj_name)
    if(MSVC)
        target_compile_options(${proj_name} PRIVATE /W4)
        if(CM_WARNINGS_AS_ERRORS)
            target_compile_options(${proj_name} PRIVATE /WX)
        endif()
    else()
        target_compile_options(${proj_name} PRIVATE -Wall -Wextra -Wpedantic)
        if(CM_WARNINGS_AS_ERRORS)
            target_compile_options(${proj_name} PRIVATE -Werror)
        endif()

        # Address Sanitizer Toggle
        if(CM_ENABLE_ASAN)
            message(DEBUG "[cm]·· Enabling ASan for ${proj_name}")
            target_compile_options(${proj_name} PRIVATE -fsanitize=address)
            target_link_options(${proj_name} PRIVATE -fsanitize=address)
        endif()
    endif()
endfunction()

# -----------------------------------------------------------------------------
# EXTERNAL DEPENDENCY MANAGEMENT
# -----------------------------------------------------------------------------
function(cm_ADD_DEP lib_name lib_version lib_url sys_first)
    if (${sys_first})
        find_package(${lib_name} ${lib_version} QUIET)
    endif()

    if (NOT ${lib_name}_FOUND)
        message(STATUS "[cm] · External : ${lib_name}")
        FetchContent_Declare(${lib_name} DOWNLOAD_EXTRACT_TIMESTAMP OFF URL ${lib_url})
        FetchContent_MakeAvailable(${lib_name})
    else()
        message(STATUS "[cm] · System   : ${lib_name}")
    endif()

    # Safely append to the global list using native CMake lists
    set(l_TMP ${cm_DEPS})
    list(APPEND l_TMP ${lib_name})
    list(REMOVE_DUPLICATES l_TMP)
    set(cm_DEPS "${l_TMP}" CACHE INTERNAL "Global external dependencies list")

    message("")
endfunction()

function(cm_LINK_DEPS proj_name)
    if(cm_DEPS)
        target_link_libraries(${proj_name} PRIVATE ${cm_DEPS})
    endif()
endfunction()

# -----------------------------------------------------------------------------
# INTERNAL DEPENDENCY MANAGEMENT (NAMESPACED)
# -----------------------------------------------------------------------------
function(cm_LINK_INTERNAL proj_name)
    if(ARGN)
        message(STATUS "[cm] · Internal : ${proj_name} linking to [${ARGN}]")
        target_link_libraries(${proj_name} PRIVATE ${ARGN})
    endif()
endfunction()

# -----------------------------------------------------------------------------
# UTILITIES
# -----------------------------------------------------------------------------
function(cm_SET_OUTPUT_DIR proj_name dir_name)
    set(l_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../${dir_name}")
    message(DEBUG "[cm]·· OutputDir -> ${l_OUTPUT_DIR}")

    set_target_properties(${proj_name} PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        LIBRARY_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}"
    )
endfunction()

function(cm_GLOB root_dir out_sources out_headers)
    file(GLOB l_SOURCES "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c")
    set(${out_sources} "${l_SOURCES}" PARENT_SCOPE)

    file(GLOB l_HEADERS "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h")
    set(${out_headers} "${l_HEADERS}" PARENT_SCOPE)
endfunction()

function (cm_HAS_CMAKEFILE root_dir out_has_cmakefile)
    file(GLOB l_CMAKEFILE "${root_dir}/[Cc][Mm][Aa][Kk][Ee][Ll][Ii][Ss][Tt][Ss].txt")
    if(l_CMAKEFILE)
        set(${out_has_cmakefile} ON PARENT_SCOPE)
    else()
        set(${out_has_cmakefile} OFF PARENT_SCOPE)
    endif()
endfunction()

# -----------------------------------------------------------------------------
# TARGET SETUP: EXECUTABLES
# -----------------------------------------------------------------------------
function(cm_ADD_EXE proj_name proj_root_dir)
    cm_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)
    message(STATUS "[cm] · Project  : ${proj_name}")
    add_executable(${proj_name} ${l_SOURCES} ${l_HEADERS})
endfunction()

function(cm_SETUP_EXE)
    set(a_LINK_DEPS ${ARGN})
    list(POP_FRONT a_LINK_DEPS l_DO_LINK)

    get_filename_component(l_NAME_AUX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" l_NAME "${l_NAME_AUX}")
    project(${l_NAME})

    cm_ADD_EXE(${PROJECT_NAME} ${PROJECT_SOURCE_DIR})
    cm_SET_OUTPUT_DIR(${PROJECT_NAME} "bin/${PROJECT_NAME}")

    set_target_properties(${PROJECT_NAME} PROPERTIES
        CXX_EXTENSIONS OFF
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
        EXPORT_COMPILE_COMMANDS ON
    )

    target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCE_DIR})
    cm_ENABLE_STRICT_MODE(${PROJECT_NAME})

    if (l_DO_LINK)
        cm_LINK_DEPS(${PROJECT_NAME})
    endif()
endfunction()

# -----------------------------------------------------------------------------
# TARGET SETUP: COMPILED LIBRARIES
# -----------------------------------------------------------------------------
function(cm_ADD_LIB proj_name proj_root_dir lib_type)
    cm_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)
    message(STATUS "[cm] · Library  : ${proj_name} (${lib_type})")
    add_library(${proj_name} ${lib_type} ${l_SOURCES} ${l_HEADERS})
endfunction()

function(cm_SETUP_LIB lib_type)
    set(a_LINK_DEPS ${ARGN})
    list(POP_FRONT a_LINK_DEPS l_DO_LINK)

    get_filename_component(l_NAME_AUX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" l_NAME "${l_NAME_AUX}")
    project(${l_NAME})

    cm_ADD_LIB(${PROJECT_NAME} ${PROJECT_SOURCE_DIR} ${lib_type})

    # Create the ALIAS target (Namespacing)
    add_library(${cm_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    cm_SET_OUTPUT_DIR(${PROJECT_NAME} "lib/${PROJECT_NAME}")

    set_target_properties(${PROJECT_NAME} PROPERTIES
        CXX_EXTENSIONS OFF
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
        EXPORT_COMPILE_COMMANDS ON
    )

    target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCE_DIR})
    cm_ENABLE_STRICT_MODE(${PROJECT_NAME})

    if (l_DO_LINK)
        cm_LINK_DEPS(${PROJECT_NAME})
    endif()
endfunction()

# -----------------------------------------------------------------------------
# TARGET SETUP: HEADER-ONLY LIBRARIES
# -----------------------------------------------------------------------------
function(cm_SETUP_HEADER_LIB)
    set(a_LINK_DEPS ${ARGN})
    list(POP_FRONT a_LINK_DEPS l_DO_LINK)

    get_filename_component(l_NAME_AUX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" l_NAME "${l_NAME_AUX}")
    project(${l_NAME})

    message(STATUS "[cm] · HeaderLib: ${PROJECT_NAME}")

    add_library(${PROJECT_NAME} INTERFACE)

    # Create the ALIAS target (Namespacing)
    add_library(${cm_TOPNAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

    target_include_directories(${PROJECT_NAME} INTERFACE ${PROJECT_SOURCE_DIR})

    cm_GLOB(${PROJECT_SOURCE_DIR} l_SOURCES l_HEADERS)
    if(l_HEADERS)
        target_sources(${PROJECT_NAME} INTERFACE ${l_HEADERS})
    endif()

    if (l_DO_LINK AND cm_DEPS)
        target_link_libraries(${PROJECT_NAME} INTERFACE ${cm_DEPS})
    endif()
endfunction()

# -----------------------------------------------------------------------------
# SUBDIRECTORY DETECTION
# -----------------------------------------------------------------------------
function(cm_DETECT_PROJECTS)
    set(l_FOUND_DIRS "")
    set(l_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

    file(GLOB l_ROOT_CONTENT LIST_DIRECTORIES TRUE RELATIVE "${l_ROOT_DIR}" "${l_ROOT_DIR}/*")

    foreach(l_ITEM ${l_ROOT_CONTENT})
        set(l_ITEM_DIR "${l_ROOT_DIR}/${l_ITEM}")
        cm_HAS_CMAKEFILE("${l_ITEM_DIR}" l_HAS_CMAKEFILE)

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

# -----------------------------------------------------------------------------
# TESTS
# -----------------------------------------------------------------------------
function(cm_ENABLE_TESTS)
    message(STATUS "[cm] · Enabling tests")
    enable_testing()
    cm_GLOB("${CMAKE_SOURCE_DIR}/tests" _sources _headers)

    foreach(_source IN LISTS _sources)
        get_filename_component(_name "${_source}" NAME_WE)
        add_executable(${_name} "${_source}")

        cm_SET_OUTPUT_DIR(${_name} "tests")
        cm_ENABLE_STRICT_MODE(${_name})
        cm_LINK_DEPS(${_name})

        add_test(NAME "${_name}" COMMAND "${_name}")
        message(STATUS "[cm] · Test     : ${_name} -- ${_source}")
    endforeach()
    message("")
endfunction()
