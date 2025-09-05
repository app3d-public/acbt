
# Normalizes a variable name
# Example: My App-1 -> MY_APP_1
function(normalize_variable_name INPUT OUT_VAR)
    if(DEFINED ${INPUT})
        set(_s "${${INPUT}}")
    else()
        set(_s "${INPUT}")
    endif()

    string(REGEX MATCHALL "([a-zA-Z0-9]+)" _tokens "${_s}")

    set(_result "")

    foreach(tok IN LISTS _tokens)
        string(TOUPPER "${tok}" tok)

        if(_result STREQUAL "")
            set(_result "${tok}")
        else()
            set(_result "${_result}_${tok}")
        endif()
    endforeach()

    set(${OUT_VAR} "${_result}" PARENT_SCOPE)
endfunction()

if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(ACBT_COMMON_H TRUE PARENT_SCOPE)
endif()