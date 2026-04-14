include_guard(GLOBAL)

include(CMakeParseArguments)

if(NOT DEFINED ACBT_COMMON_H)
    include(${CMAKE_CURRENT_LIST_DIR}/common.cmake)
endif()

function(get_target_output_dir target_name out_var)
    get_target_property(target_output_dir ${target_name} RUNTIME_OUTPUT_DIRECTORY)

    if(NOT target_output_dir OR target_output_dir STREQUAL "target_output_dir-NOTFOUND")
        if(CMAKE_RUNTIME_OUTPUT_DIRECTORY)
            set(target_output_dir "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
        else()
            set(target_output_dir "${CMAKE_CURRENT_BINARY_DIR}")
        endif()
    endif()

    get_filename_component(target_output_dir "${target_output_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    set(${out_var} "${target_output_dir}" PARENT_SCOPE)
endfunction()

function(find_nuget_exe out_var)
    find_program(nuget_exe NAMES nuget nuget.exe
        HINTS "${CMAKE_SOURCE_DIR}" "$ENV{NUGET_EXE}")
    if(NOT nuget_exe)
        message(FATAL_ERROR "nuget.exe was not found. Put it in PATH or next to the root CMakeLists.txt.")
    endif()
    set(${out_var} "${nuget_exe}" PARENT_SCOPE)
endfunction()

function(find_cppwinrt_exe out_var)
    find_program(cppwinrt_exe NAMES cppwinrt cppwinrt.exe)
    if(NOT cppwinrt_exe)
        message(FATAL_ERROR "cppwinrt.exe was not found. Install C++/WinRT tooling or add it to PATH.")
    endif()
    set(${out_var} "${cppwinrt_exe}" PARENT_SCOPE)
endfunction()

function(get_windows_dll_file_version dll_path out_var)
    if(NOT WIN32)
        message(FATAL_ERROR "get_windows_dll_file_version() is supported only on Windows")
    endif()

    if(NOT EXISTS "${dll_path}")
        message(FATAL_ERROR "get_windows_dll_file_version(): file does not exist: ${dll_path}")
    endif()

    find_program(ACBT_POWERSHELL_EXE NAMES powershell powershell.exe REQUIRED)
    execute_process(
        COMMAND "${ACBT_POWERSHELL_EXE}" -NoProfile -ExecutionPolicy Bypass
            "(Get-Item '${dll_path}').VersionInfo.FileVersion"
        OUTPUT_VARIABLE dll_file_version
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    if(NOT dll_file_version)
        message(FATAL_ERROR
            "get_windows_dll_file_version(): failed to read FileVersion from ${dll_path}")
    endif()

    set(${out_var} "${dll_file_version}" PARENT_SCOPE)
endfunction()

function(nuget_install_package)
    set(options)
    set(one_value_args PACKAGE_NAME PACKAGE_VERSION OUTPUT_DIRECTORY DEPENDENCY_VERSION)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "" ${ARGN})

    if(NOT ARG_PACKAGE_NAME OR NOT ARG_PACKAGE_VERSION OR NOT ARG_OUTPUT_DIRECTORY)
        message(FATAL_ERROR
            "nuget_install_package() requires PACKAGE_NAME, PACKAGE_VERSION and OUTPUT_DIRECTORY")
    endif()

    if(NOT ARG_DEPENDENCY_VERSION)
        set(ARG_DEPENDENCY_VERSION "HighestPatch")
    endif()

    find_nuget_exe(nuget_exe)

    string(TOLOWER "${ARG_PACKAGE_NAME}" package_name_lower)
    if(DEFINED ENV{NUGET_PACKAGES} AND NOT "$ENV{NUGET_PACKAGES}" STREQUAL "")
        set(global_packages_root "$ENV{NUGET_PACKAGES}")
    else()
        set(global_packages_root "$ENV{USERPROFILE}/.nuget/packages")
    endif()

    set(package_root "${ARG_OUTPUT_DIRECTORY}/${ARG_PACKAGE_NAME}.${ARG_PACKAGE_VERSION}")
    set(global_package_root "${global_packages_root}/${package_name_lower}/${ARG_PACKAGE_VERSION}")
    file(MAKE_DIRECTORY "${ARG_OUTPUT_DIRECTORY}")

    if(NOT EXISTS "${package_root}")
        if(EXISTS "${global_package_root}")
            message(STATUS "Copying cached ${ARG_PACKAGE_NAME} ${ARG_PACKAGE_VERSION} into ${ARG_OUTPUT_DIRECTORY}")
            file(MAKE_DIRECTORY "${package_root}")
            file(COPY "${global_package_root}/" DESTINATION "${package_root}")
        else()
            message(STATUS "Installing ${ARG_PACKAGE_NAME} ${ARG_PACKAGE_VERSION} into ${ARG_OUTPUT_DIRECTORY}")
            execute_process(
                COMMAND "${nuget_exe}" install "${ARG_PACKAGE_NAME}"
                    -Version "${ARG_PACKAGE_VERSION}"
                    -OutputDirectory "${ARG_OUTPUT_DIRECTORY}"
                    -DependencyVersion "${ARG_DEPENDENCY_VERSION}"
                    -Source "https://api.nuget.org/v3/index.json"
                    -NonInteractive
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
                COMMAND_ERROR_IS_FATAL ANY
            )
        endif()
    endif()
endfunction()

function(add_cppwinrt_target)
    set(options)
    set(one_value_args TARGET_NAME OUTPUT_DIR INPUT_WINMD)
    set(multi_value_args REF_WINMDS DEPENDS)
    cmake_parse_arguments(ARG "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    if(NOT ARG_TARGET_NAME OR NOT ARG_OUTPUT_DIR OR NOT ARG_INPUT_WINMD)
        message(FATAL_ERROR
            "add_cppwinrt_target() requires TARGET_NAME, OUTPUT_DIR and INPUT_WINMD")
    endif()

    find_cppwinrt_exe(cppwinrt_exe)

    set(cppwinrt_stamp "${ARG_OUTPUT_DIR}/.stamp")
    set(cppwinrt_args -out "${ARG_OUTPUT_DIR}" -ref sdk)

    foreach(ref_winmd IN LISTS ARG_REF_WINMDS)
        list(APPEND cppwinrt_args -ref "${ref_winmd}")
    endforeach()

    list(APPEND cppwinrt_args -in "${ARG_INPUT_WINMD}")

    add_custom_command(
        OUTPUT "${cppwinrt_stamp}"
        COMMAND "${CMAKE_COMMAND}" -E rm -rf "${ARG_OUTPUT_DIR}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${ARG_OUTPUT_DIR}"
        COMMAND "${cppwinrt_exe}" ${cppwinrt_args}
        COMMAND "${CMAKE_COMMAND}" -E touch "${cppwinrt_stamp}"
        DEPENDS
            "${ARG_INPUT_WINMD}"
            ${ARG_REF_WINMDS}
            ${ARG_DEPENDS}
        COMMENT "Generating C++/WinRT headers: ${ARG_TARGET_NAME}"
        VERBATIM
    )

    add_custom_target(${ARG_TARGET_NAME}
        DEPENDS "${cppwinrt_stamp}")
endfunction()
