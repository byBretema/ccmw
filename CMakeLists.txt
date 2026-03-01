set(TopCmakeMinVer 3.28)
cmake_minimum_required(VERSION ${TopCmakeMinVer})

include(.cmake/cm.cmake)

get_filename_component(TopName ${CMAKE_CURRENT_SOURCE_DIR} NAME)
project(${TopName})

set(CMAKE_COMPILE_WARNING_AS_ERROR ON)

message("")
cm_ADD_DEP("argparse" "3.2" "https://github.com/p-ranav/argparse/archive/refs/tags/v3.2.zip" OFF)

cm_DETECT_PROJECTS()
