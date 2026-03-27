cmake_minimum_required(VERSION 3.28)

include(vendor/nest.cmake)
project(${nest_TOPNAME})

nest_INIT(20)

# nest_LOAD_DEPENDENCIES()
nest_ADD_DEP(glm 1.0.3 https://github.com/g-truc/glm/archive/refs/tags/1.0.3.zip OFF)

nest_DETECT_PROJECTS()
