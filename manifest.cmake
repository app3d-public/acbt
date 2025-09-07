set(MANIFEST_LIB ${TEMPLATES_DIR}/lib.manifest.in)
set(MANIFEST_APP ${TEMPLATES_DIR}/app.manifest.in)

# Generate dependencies for Windows Manifest files
function(gen_manifest_dependencies DEPENDENCY_LIST OUT_VAR)
    set(DEPENDENCY_BLOCK "")

    foreach(DEP_PAIR IN LISTS DEPENDENCY_LIST)
        string(REGEX MATCH "([^:]+):([0-9]+\\.[0-9]+\\.[0-9]+)(\\.[0-9]+)?" MATCHES "${DEP_PAIR}")
        set(DEP_NAME "${CMAKE_MATCH_1}")
        set(DEP_VERSION "${CMAKE_MATCH_2}${CMAKE_MATCH_3}")

        if("${CMAKE_MATCH_3}" STREQUAL "")
            set(DEP_VERSION "${DEP_VERSION}.0")
        endif()

        string(APPEND DEPENDENCY_BLOCK
            "    <dependency>\n"
            "        <dependentAssembly>\n"
            "            <assemblyIdentity type=\"win32\" name=\"${DEP_NAME}\" version=\"${DEP_VERSION}\" />\n"
            "        </dependentAssembly>\n"
            "    </dependency>\n")
    endforeach()

    set(${OUT_VAR} "${DEPENDENCY_BLOCK}" PARENT_SCOPE)
endfunction()

function(gen_manifest_lib PACKAGE_NAME PACKAGE_VERSION)
    # Нормализуем версию до 4-частной: x.y.z  -> x.y.z.0,  x.y.z.w -> как есть
    if(NOT PACKAGE_VERSION)
        message(FATAL_ERROR "gen_manifest_lib(${PACKAGE_NAME}): PACKAGE_VERSION is empty")
    endif()

    string(REGEX MATCH "^([0-9]+\\.[0-9]+\\.[0-9]+)(\\.[0-9]+)?$" _ "${PACKAGE_VERSION}")
    if(NOT CMAKE_MATCH_0)
        message(FATAL_ERROR
            "gen_manifest_lib(${PACKAGE_NAME}): invalid version '${PACKAGE_VERSION}'. "
            "Expected 'x.y.z' or 'x.y.z.w'")
    endif()

    set(_PKG_VERSION "${CMAKE_MATCH_1}${CMAKE_MATCH_2}")
    if("${CMAKE_MATCH_2}" STREQUAL "")
        set(_PKG_VERSION "${_PKG_VERSION}.0")
    endif()

    if(DEFINED APP_LIB_DIR)
        set(OUT_PATH "${APP_LIB_DIR}/${PACKAGE_NAME}.manifest")
    elseif(CMAKE_RUNTIME_OUTPUT_DIRECTORY)
        set(OUT_PATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${PACKAGE_NAME}.manifest")
    else()
        set(OUT_PATH "${CMAKE_BINARY_DIR}/${PACKAGE_NAME}.manifest")
    endif()

    set(PACKAGE_NAME    "${PACKAGE_NAME}")
    set(PACKAGE_VERSION "${_PKG_VERSION}")

    configure_file("${MANIFEST_LIB}" "${OUT_PATH}" @ONLY)
endfunction()

function(gen_manifest_app PACKAGE_NAME PACKAGE_VERSION)
    get_target_property(TARGET_PATH ${PACKAGE_NAME} RUNTIME_OUTPUT_DIRECTORY)
    set(OUT_PATH)

    if(TARGET_PATH)
        set(OUT_PATH ${TARGET_PATH}/${PROJECT_NAME}.exe.manifest)
    else()
        set(OUT_PATH ${CMAKE_BINARY_DIR}/${PROJECT_NAME}.exe.manifest)
    endif()

    gen_manifest_dependencies("${ARGN}" PACKAGE_DEPENDENCIES)
    configure_file(${MANIFEST_APP} ${OUT_PATH})
endfunction()

function(gen_app_config)
    get_target_property(TARGET_PATH ${PROJECT_NAME} RUNTIME_OUTPUT_DIRECTORY)
    set(OUT_PATH)

    if(TARGET_PATH)
        set(OUT_PATH ${TARGET_PATH}/${PROJECT_NAME}.exe.config)
    else()
        set(OUT_PATH ${CMAKE_BINARY_DIR}/${PROJECT_NAME}.exe.config)
    endif()

    if(DEFINED APP_LIB_DIR)
        if(TARGET_PATH)
            file(RELATIVE_PATH LIBRARY_PATH "${TARGET_PATH}" "${APP_LIB_DIR}")
        else()
            file(RELATIVE_PATH LIBRARY_PATH "${CMAKE_BINARY_DIR}" "${APP_LIB_DIR}")
        endif()
    else()
        set(LIBRARY_PATH ".")
    endif()

    configure_file(${TEMPLATES_DIR}/app.config.in ${OUT_PATH})
endfunction()

if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(MANIFEST_LIB ${MANIFEST_LIB} PARENT_SCOPE)
    set(MANIFEST_APP ${MANIFEST_APP} PARENT_SCOPE)
endif()