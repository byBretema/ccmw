include(FetchContent)

set(FETCHCONTENT_BASE_DIR ${CMAKE_SOURCE_DIR}/build/deps)
set(cm_DEPS "" CACHE INTERNAL "")

macro(cm_OLD_STYLE_DEFAULTS cxx_standard)

    if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Debug)
    endif()

    set(CMAKE_CXX_STANDARD ${cxx_standard})
    set(CMAKE_CXX_EXTENSIONS OFF)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    if(IS_DIRECTORY "${PROJECT_SOURCE_DIR}/vendor")
        include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_SOURCE_DIR}/vendor")
    endif()

    message("")

endmacro()

function(cm_ADD_DEP lib_name lib_version lib_url sys_first)

    if (${sys_first})
        find_package(${lib_name} ${lib_version} QUIET)
    endif()

    if (NOT ${lib_name}_FOUND)
        message(STATUS "[cm] · External : ${lib_name}")
        FetchContent_Declare(${lib_name} DOWNLOAD_EXTRACT_TIMESTAMP OFF URL ${lib_url})
        FetchContent_MakeAvailable(${lib_name})
    else()
        message(STATUS "[cm] · System : ${lib_name}")
    endif()

    set(l_TMP "${cm_DEPS} ${lib_name}")
    string(STRIP ${l_TMP} l_CLEAN)
    set(cm_DEPS "${l_CLEAN}" CACHE INTERNAL "")

    message("")

endfunction()

function(cm_LINK_DEPS proj_name)

    string(REPLACE " " ";" _deps "${cm_DEPS}")
    # message(DEBUG "[cm]·· Linking -> ${cm_DEPS}")
    target_link_libraries(${proj_name} ${_deps})

endfunction()

function(cm_SET_OUTPUT_DIR proj_name dir_name)

    if (NOT MSVC)
       set(l_BUILD_TYPE ${CMAKE_BUILD_TYPE})
    else()
        set(l_BUILD_TYPE "")
    endif()

    set(l_OUTPUT_DIR "${CMAKE_BINARY_DIR}/../${dir_name}")
    message(DEBUG "[cm]·· OutputDir -> ${l_OUTPUT_DIR}")

    set_target_properties(${proj_name} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}")
    set_target_properties(${proj_name} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}")
    set_target_properties(${proj_name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${l_OUTPUT_DIR}")

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

function(cm_ADD_EXE proj_name proj_root_dir)

    # Include the headers to help IDEs
    # -- https://blog.conan.io/2019/09/02/Deterministic-builds-with-C-C++.html

    cm_GLOB(${proj_root_dir} l_SOURCES l_HEADERS)

    message(STATUS "[cm] · Project : ${proj_name}")

    message(DEBUG "  -- ${proj_root_dir}")
    message(DEBUG "  -- Sources :")
    foreach(l_SOURCE IN LISTS l_SOURCES)
        message(DEBUG "  ---- ${l_SOURCE}")
    endforeach()
    message(DEBUG "  -- Headers :")
    foreach(l_HEADER IN LISTS l_HEADERS)
        message(DEBUG "  ---- ${l_HEADER}")
    endforeach()

    add_executable(${proj_name} ${l_SOURCES} ${l_HEADERS})

endfunction()

function(cm_SETUP_EXE)
    list(POP_FRONT ARGN a_LINK_DEPS)

    get_filename_component(l_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    project(${l_NAME})

    cm_ADD_EXE(${PROJECT_NAME} ${PROJECT_SOURCE_DIR})

    # Output
    cm_SET_OUTPUT_DIR(${PROJECT_NAME} "bin/${PROJECT_NAME}")

    # Properties
    set_target_properties(${PROJECT_NAME}
        PROPERTIES
            CMAKE_CXX_EXTENSIONS OFF
            CMAKE_CXX_VISIBILITY_PRESET hidden
            CMAKE_VISIBILITY_INLINES_HIDDEN ON
            CMAKE_EXPORT_COMPILE_COMMANDS ON
    )

    # Includes
    target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCE_DIR})

    # Dependencies
    if (a_LINK_DEPS)
        cm_LINK_DEPS(${PROJECT_NAME})
    endif()

endfunction()

function(cm_DETECT_PROJECTS)

    set(l_FOUND_DIRS "")
    set(l_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

    # Get everything
    file(GLOB l_ROOT_CONTENT LIST_DIRECTORIES TRUE RELATIVE "${l_ROOT_DIR}" "${l_ROOT_DIR}/*")

    # Filter valid folders
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

    # Add subdirs
    foreach(l_DIR ${l_FOUND_DIRS})
        # message(STATUS "[cm] · Project : ${l_DIR}")
        add_subdirectory("${l_DIR}")
        message("")
    endforeach()

endfunction()

function(cm_ENABLE_TESTS)

    # if(NOT cm_BUILD_TESTS)
        # return()
    # endif()

    message(STATUS "[cm] · Enabling tests")

    enable_testing()

    cm_GLOB("${CMAKE_SOURCE_DIR}/tests" _sources _headers)

    foreach(_source IN LISTS _sources)

        get_filename_component(_name "${_source}" NAME_WE)
        add_executable(${_name} "${_source}")

        cm_SET_OUTPUT_DIR(${_name} "tests")
        cm_LINK_DEPS(${_name})

        add_test(NAME "${_name}" COMMAND "${_name}")

        message(STATUS "[cm] · Test : ${_name} -- ${_source}")

    endforeach()
    message("")

endfunction()

