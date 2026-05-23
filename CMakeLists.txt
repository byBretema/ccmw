cmake_minimum_required(VERSION 3.28)

include(cmake/nest.cmake)
project(${nest_TOPNAME})

nest_INIT(20)

nest_ADD_DEP(glm 1.0.3 https://github.com/g-truc/glm/archive/refs/tags/1.0.3.zip OFF)
nest_ADD_DEP(fmt 11.1.4 https://github.com/fmtlib/fmt/releases/download/11.1.4/fmt-11.1.4.zip OFF)

nest_DETECT_PROJECTS()
enable_testing()
nest_ENABLE_TESTS()

# add_subdirectory(mylib1)
# add_subdirectory(demo2)
