include(CheckCXXSourceCompiles)

if(NOT DEFINED ACBT_COMMON_H)
    include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)
endif()

# Check ISA features
function(check_compiler_define DEFINE RESULT)
    set(OLD_REQ_FLAGS "${CMAKE_REQUIRED_FLAGS}")
    set(CMAKE_REQUIRED_FLAGS "-march=native")
    CHECK_CXX_SOURCE_COMPILES("
    #include <limits.h>
    #ifndef ${DEFINE}
    #error \"${DEFINE} is not a macro!\"
    #endif
    int main() { return 0; }
    " ${RESULT})
    set(${RESULT} ${${RESULT}} PARENT_SCOPE)
    set(CMAKE_REQUIRED_FLAGS "${OLD_REQ_FLAGS}")
    set(${RESULT} ${${RESULT}} PARENT_SCOPE)
endfunction()

check_compiler_define("__AVX__" ISA_AVX)
check_compiler_define("__AVX2__" ISA_AVX2)
check_compiler_define("__AVX512F__" ISA_AVX512)
check_compiler_define("__SSE4_2__" ISA_SSE42)

set(ISA_DEFAULT TRUE)
set(PREFIX_isa "avx512;ISA_AVX512" "avx2;ISA_AVX2" "avx;ISA_AVX" "sse42;ISA_SSE42" "scalar;ISA_DEFAULT")
list(LENGTH PREFIX_isa list_length)
math(EXPR max_index "${list_length} - 1")

foreach(idx RANGE 0 ${max_index} 2)
    math(EXPR next_idx "${idx} + 1")
    list(GET PREFIX_isa ${idx} item1)
    list(GET PREFIX_isa ${next_idx} item2)

    if(NOT ${item2})
        continue()
    else()
        set(APP_ISA_ARCH ${item1})
        break()
    endif()
endforeach()

set(PREFIX_os "win32;WIN32" "linux;LINUX" "osx;APPLE")

# Checks if a file exists and sets a variable to the result.
function(is_file_exists file_list target_file result_var)
    list(FIND file_list "${target_file}" index)

    if(index GREATER_EQUAL 0)
        set(${result_var} TRUE PARENT_SCOPE)
    else()
        set(${result_var} FALSE PARENT_SCOPE)
    endif()
endfunction()

# Checks if a given pair is present in a list and sets a variable to the result.
macro(list_contains_pair LIST_VAR VALUE RESULT_VAR)
    set(${RESULT_VAR} FALSE)

    if(DEFINED ${LIST_VAR})
        list(LENGTH ${LIST_VAR} list_length)

        if(list_length GREATER 1)
            math(EXPR max_index "${list_length} - 1")

            foreach(idx RANGE 0 ${max_index} 2)
                math(EXPR next_idx "${idx} + 1")
                list(GET ${LIST_VAR} ${idx} item1)
                list(GET ${LIST_VAR} ${next_idx} item2)

                if("${item1};${item2}" STREQUAL "${VALUE}")
                    set(${RESULT_VAR} TRUE)
                    break()
                endif()
            endforeach()
        endif()
    endif()
endmacro()

# Filters a list of files based on a given pattern and outputs the filtered list to another variable.
function(filter_files FILE_LIST OUT_LIST)
    foreach(file ${FILE_LIST})
        string(REGEX REPLACE "(.*)__([a-z]+)_[a-z0-9]+_(.*)" "\\1;\\2;\\3" PREFIXES ${file})
        list(LENGTH PREFIXES count)

        if(count GREATER 1)
            list(GET PREFIXES 0 ABS_PATH)
            list(GET PREFIXES 1 PREFIX)
            list(GET PREFIXES 2 FILE_BASENAME)
            set(FEATURE_VAR "PREFIX_${PREFIX}_FOUNDS")

            if(DEFINED ${FEATURE_VAR} AND NOT "${${FEATURE_VAR}}" STREQUAL "")
                set(FILE_PROCESS_CHECK "${ABS_PATH}${FILE_BASENAME}")
                list_contains_pair(${FEATURE_VAR} "${FILE_PROCESS_CHECK}" FILE_ALREADY_PROCESSED)

                if(FILE_ALREADY_PROCESSED)
                    continue()
                endif(FILE_ALREADY_PROCESSED)
            endif()

            set(PREFIX_LIST_VAR "PREFIX_${PREFIX}")

            if(DEFINED ${PREFIX_LIST_VAR})
                list(LENGTH "PREFIX_${PREFIX}" prefix_length)
                math(EXPR max_index "${prefix_length} - 1")

                foreach(idx RANGE 0 ${max_index} 2)
                    math(EXPR next_idx "${idx} + 1")
                    list(GET "PREFIX_${PREFIX}" ${idx} current_prefix)
                    list(GET "PREFIX_${PREFIX}" ${next_idx} current_feature)

                    if(NOT ${current_feature})
                        continue()
                    endif()

                    set(TO_FIND_NAME "${ABS_PATH}__${PREFIX}_${current_prefix}_${FILE_BASENAME}")
                    is_file_exists("${FILE_LIST}" ${TO_FIND_NAME} FILE_FOUND)

                    if(FILE_FOUND)
                        list(APPEND PREFIX_${PREFIX}_FOUNDS "${ABS_PATH};${FILE_BASENAME}")
                        list(APPEND OUT_LIST ${TO_FIND_NAME})
                        break()
                    endif()
                endforeach()
            else()
                message(SEND_ERROR "Prefix does not match any pattern: ${PREFIX}")
            endif()
        else()
            list(APPEND OUT_LIST ${file})
        endif()
    endforeach()

    set(${OUT_LIST} ${${OUT_LIST}} PARENT_SCOPE)
endfunction()

# Adds files to a given target
function(add_files target_name)
    set(options RECURSE)
    set(one_value_args)
    set(multi_value_args)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "${multi_value_args}")

    set(APP_MODULES_LIST "")

    foreach(BASE_DIR ${ARG_UNPARSED_ARGUMENTS})
        list(APPEND APP_MODULES_LIST "${BASE_DIR}/*.cpp")

        if(APPLE)
            list(APPEND APP_MODULES_LIST "${BASE_DIR}/*.mm")
        endif()
    endforeach()

    foreach(APP_MODULE_PATH ${APP_MODULES_LIST})
        if(ARG_RECURSE)
            file(GLOB_RECURSE TEMP_APP_MODULE_SRC ${APP_MODULE_PATH})
        else()
            file(GLOB TEMP_APP_MODULE_SRC ${APP_MODULE_PATH})
        endif()

        filter_files("${TEMP_APP_MODULE_SRC}" FILTERED_FILES)
        list(APPEND SOURCE_FILES ${FILTERED_FILES})
    endforeach()

    normalize_variable_name(target_name TARGET_NAME_VAR)
    set(${TARGET_NAME_VAR}_SRC ${SOURCE_FILES} ${${TARGET_NAME_VAR}_SRC} PARENT_SCOPE)
endfunction()

set(TEMPLATES_DIR ${CMAKE_CURRENT_LIST_DIR}/templates)

function(add_test_files TEST_LABEL TEST_NAME TEST_SOURCE_FILE)
    set(TEST_FINAL_NAME "${TEST_LABEL}_${TEST_NAME}")
    set(MAIN_PATH ${CMAKE_BINARY_DIR}/tests/src/${TEST_FINAL_NAME}.cpp)
    configure_file(${TEMPLATES_DIR}/test.cpp.in ${MAIN_PATH})
    list(APPEND TEST_SOURCES ${MAIN_PATH} ${TEST_SOURCE_FILE})
    add_executable(${TEST_FINAL_NAME} ${TEST_SOURCES})

    target_compile_definitions(${TEST_FINAL_NAME} PRIVATE PROCESS_UNITTEST)

    if(DEFINED TEST_INCLUDES)
        target_include_directories(${TEST_FINAL_NAME} PRIVATE ${TEST_INCLUDES})
    endif()

    set(TEST_WORK_DIR)

    if(DEFINED APP_LIB_DIR)
        set(TEST_WORK_DIR ${APP_LIB_DIR})
    else()
        set(TEST_WORK_DIR ${CMAKE_BINARY_DIR})
    endif()

    add_test(NAME ${TEST_FINAL_NAME} COMMAND "${CMAKE_BINARY_DIR}/tests/${TEST_FINAL_NAME}" WORKING_DIRECTORY ${TEST_WORK_DIR})

    if(DEFINED TEST_LIBRARIES)
        target_link_libraries(${TEST_FINAL_NAME} PRIVATE ${TEST_LIBRARIES})
    endif()

    set_tests_properties(${TEST_FINAL_NAME} PROPERTIES LABELS ${TEST_LABEL})

    set(env_vars "")

    if(DEFINED TEST_ENV)
        list(APPEND env_vars ${TEST_ENV})
    endif()

    if(ENABLE_COVERAGE)
        list(APPEND env_vars "LLVM_PROFILE_FILE=${CMAKE_BINARY_DIR}/tests/coverage/${TEST_FINAL_NAME}.profraw")
        target_compile_options(${TEST_FINAL_NAME} PRIVATE -fno-inline)
    endif()

    if(env_vars)
        set_tests_properties(${TEST_FINAL_NAME} PROPERTIES ENVIRONMENT "${env_vars}")
    endif()

    set_target_properties(${TEST_FINAL_NAME}
        PROPERTIES
        CXX_EXTENSIONS YES
    )

    list(APPEND TEST_${TEST_LABEL}_ALL_NAMES ${TEST_NAME})
    set(TEST_${TEST_LABEL}_ALL_NAMES "${TEST_${TEST_LABEL}_ALL_NAMES}" PARENT_SCOPE)

    list(APPEND TEST_${TEST_LABEL}_ALL_SOURCES ${TEST_SOURCE_FILE})
    set(TEST_${TEST_LABEL}_ALL_SOURCES "${TEST_${TEST_LABEL}_ALL_SOURCES}" PARENT_SCOPE)
endfunction()

# Make app includes all tests
function(add_test_coverage TEST_LABEL)
    set(MAIN_PATH ${CMAKE_BINARY_DIR}/tests/src/${TEST_LABEL}_all.cpp)
    file(WRITE ${MAIN_PATH} "")
    set(SOURCE_FILES ${TEST_SOURCES})

    set(TEST_SOURCE_LIST ${TEST_${TEST_LABEL}_ALL_SOURCES})

    foreach(TEST_SOURCE IN LISTS TEST_SOURCE_LIST)
        list(APPEND SOURCE_FILES ${TEST_SOURCE})
    endforeach()

    set(TEST_NAMES ${TEST_${TEST_LABEL}_ALL_NAMES})

    foreach(TEST_NAME IN LISTS TEST_NAMES)
        file(APPEND "${MAIN_PATH}" "void test_${TEST_NAME}();\n")
    endforeach()

    file(APPEND "${MAIN_PATH}" "\nint main()\n{\n")

    foreach(TEST_NAME IN LISTS TEST_NAMES)
        file(APPEND "${MAIN_PATH}" "test_${TEST_NAME}();\n")
    endforeach()

    file(APPEND "${MAIN_PATH}" "    return 0;\n}\n")

    add_executable(${TEST_LABEL}_all ${MAIN_PATH} ${SOURCE_FILES})

    target_compile_definitions(${TEST_LABEL}_all PRIVATE PROCESS_UNITTEST)
    target_compile_options(${TEST_LABEL}_all PRIVATE -fno-inline)

    if(DEFINED TEST_LIBRARIES)
        target_link_libraries(${TEST_LABEL}_all PRIVATE ${TEST_LIBRARIES})
    endif()

    set_target_properties(${TEST_LABEL}_all
        PROPERTIES
        CXX_EXTENSIONS YES
    )
endfunction()

function(gen_version_file OUT_PATH)
    string(TOUPPER "${PROJECT_NAME}" APP_VERSION_NAME)
    configure_file(${TEMPLATES_DIR}/version.h.in ${OUT_PATH})
endfunction()

# Compile options functions

# Apply compile options for a list of targets
function(apply_compile_options)
    set(targets "")
    set(options "")

    set(mode "targets")

    foreach(arg IN LISTS ARGN)
        if(arg STREQUAL "OPTIONS")
            set(mode "options")
            continue()
        endif()

        if(mode STREQUAL "targets")
            list(APPEND targets ${arg})
        else()
            list(APPEND options ${arg})
        endif()
    endforeach()

    if(NOT targets)
        message(FATAL_ERROR "apply_compile_options(): no targets specified")
    endif()

    if(NOT options)
        message(FATAL_ERROR "apply_compile_options(): no OPTIONS specified")
    endif()

    foreach(tgt IN LISTS targets)
        if(NOT TARGET ${tgt})
            message(FATAL_ERROR "apply_compile_options(): target '${tgt}' does not exist")
        endif()

        target_compile_options(${tgt} PRIVATE ${options})
    endforeach()
endfunction()

include(CheckCXXCompilerFlag)

# Enable LTO
function(enable_lto)
    check_cxx_compiler_flag("-flto" HAS_LTO)

    if(HAS_LTO)
        add_compile_options("-flto")
    else()
        message(WARNING "LTO is not supported by the compiler")
    endif()
endfunction()

# Enable strip
function(enable_strip)
    check_cxx_compiler_flag("-s" HAS_STRIP)

    if(HAS_STRIP)
        add_link_options("-s")
    else()
        message(WARNING "strip is not supported by the compiler")
    endif()
endfunction()

# Enable coverage
function(enable_coverage)
    add_compile_options(-fprofile-instr-generate -fcoverage-mapping)
    add_link_options(-fprofile-instr-generate -fcoverage-mapping)
endfunction()

# Enable ASAN
function(enable_asan)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
endfunction()

function(configure_clang_toolchain)
    add_compile_options(-stdlib=libc++)
    add_link_options(-stdlib=libc++)
    add_compile_definitions(_LIBCPP_NO_VCRUNTIME)
    add_compile_options(-Wno-vla-extension)
endfunction()

set(ACBT_LOADED TRUE)

if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(ACBT_LOADED TRUE PARENT_SCOPE)
    set(TEMPLATES_DIR ${TEMPLATES_DIR} PARENT_SCOPE)
    set(PREFIX_os ${PREFIX_os} PARENT_SCOPE)
    set(PREFIX_isa ${PREFIX_isa} PARENT_SCOPE)
endif()

if(WIN32)
    include(${CMAKE_CURRENT_LIST_DIR}/manifest.cmake)
endif()