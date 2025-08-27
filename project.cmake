# Override project() to get project version
cmake_policy(SET CMP0048 NEW)

macro(project)
    _project(${ARGN})
    set(${PROJECT_NAME}_VERSION "${${PROJECT_NAME}_VERSION}" CACHE INTERNAL "")
endmacro()

if (NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(ACBT_PROJECT_LOADED TRUE PARENT_SCOPE)
else()
    set(ACBT_PROJECT_LOADED TRUE)
endif()