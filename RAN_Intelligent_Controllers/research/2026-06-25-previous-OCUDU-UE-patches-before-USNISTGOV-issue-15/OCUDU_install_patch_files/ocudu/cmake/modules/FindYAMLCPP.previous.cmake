# SPDX-FileCopyrightText: Copyright (C) 2021-2026 Software Radio Systems Limited
# SPDX-License-Identifier: BSD-3-Clause-Open-MPI


# - Try to find yaml-cpp - a YAML parser for C++
# Once done this will define
#  YAML_CPP_FOUND - System has yaml-cpp
#  YAML_CPP_VERSION - Version of the yaml-cpp library
#  Headers and libraries can be accessed with alias ocudu::yaml-cpp

unset(YAML_CPP_FOUND)

# First try to locate yaml-cpp using the CMake config mode
find_package(yaml-cpp CONFIG QUIET)

if (yaml-cpp_FOUND)
    set(YAML_CPP_FOUND TRUE)
    set(YAML_CPP_VERSION ${yaml-cpp_VERSION})
    if(TARGET yaml-cpp::yaml-cpp)
        add_library(ocudu::yaml-cpp ALIAS yaml-cpp::yaml-cpp)
    elseif(TARGET yaml-cpp)
        add_library(ocudu::yaml-cpp ALIAS yaml-cpp)
    endif()
else (yaml-cpp_FOUND)
    set(YAML_CPP_FOUND FALSE)
endif (yaml-cpp_FOUND)

if (YAML_CPP_FOUND)
    message(STATUS "Found yaml-cpp, version " ${YAML_CPP_VERSION})
endif (YAML_CPP_FOUND)
