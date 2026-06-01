cmake_minimum_required(VERSION 3.28)

include(cmake/nest.cmake)
project(${nest_TOPNAME})

nest_INIT(20)

nest_FETCH_DEP(glm 1.0.3 https://github.com/g-truc/glm/archive/refs/tags/1.0.3.zip)
nest_FETCH_DEP(fmt 11.1.4 https://github.com/fmtlib/fmt/archive/refs/tags/11.1.4.zip)

nest_DETECT_PROJECTS()
nest_ENABLE_TESTS()
