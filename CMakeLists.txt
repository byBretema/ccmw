cmake_minimum_required(VERSION 3.28)

include(vendor/nest.cmake)
project(${nest_TOPNAME})

nest_INIT(20)
nest_LOAD_DEPENDENCIES()
nest_DETECT_PROJECTS()
