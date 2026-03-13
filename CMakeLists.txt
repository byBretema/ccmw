set(cm_TOPVER 3.28)
cmake_minimum_required(VERSION ${cm_TOPVER})

include(vendor/cm_setup.cmake)
project(${cm_TOPNAME})

cm_INIT(20)
# cm_ADD_DEP("argparse" "3.2" "https://github.com/p-ranav/argparse/archive/refs/tags/v3.2.zip" OFF)
cm_DETECT_PROJECTS()

