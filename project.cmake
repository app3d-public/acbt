if(NOT DEFINED ACBT_COMMON_H)
    include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)
endif()

# Override project() to get project version
cmake_policy(SET CMP0048 NEW)

macro(project)
    _project(${ARGN})
    normalize_variable_name(PROJECT_NAME TARGET_NAME_VAR)
    set(${TARGET_NAME_VAR}_VERSION "${${PROJECT_NAME}_VERSION}" CACHE INTERNAL "")
endmacro()

set(ACBT_PROJECT_LOADED TRUE)
if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(ACBT_PROJECT_LOADED TRUE PARENT_SCOPE)
endif()
