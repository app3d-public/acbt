# App3D CMake Build Tools

ACBT is a set of CMake scripts developed as part of the App3D project. It is used to simplify and automate the build process of App3D modules.

## Acbt contains:

- Source code fetching based on feature-based naming convention
- Adding unit tests with automatic test entry point generation
- Aggregated test executables per label (with optional coverage support)
- Generation of manifest files
- Generation of version headers and resource files

## File Naming Convention
To support feature- or platform-specific implementations, source files must follow the pattern:
```sh
__<prefix>_<feature>_<name>.cpp
```
Only one version of each logical file will be selected, based on available features.

### Built-in Prefixes
| Feature | CMake Macro    | ACBT Prefix |
|---------|----------------|-------------|
| SIMD    | `__AVX512F__`  | avx512      |
| SIMD    | `__AVX2__`     | avx2        |
| SIMD    | `__AVX__`      | avx         |
| SIMD    | `__SSE4_2__`   | sse42       |
| SIMD    | (default)      | nosimd      |
| OS      | `WIN32`        | win32       |
| OS      | `LINUX`        | linux       |
| OS      | `APPLE`        | osx         |

## Output Directories
`APP_LIB_DIR` defines the common output directory for all shared libraries built in a project.  
It is an important variable in ACBT because several features depend on it:

- **Manifest and configuration generation (Microsoft Windows)**  
  When generating assembly manifests or application configuration files the probing path is derived from `APP_LIB_DIR`. If this variable is set incorrectly, Windows may fail to locate required assemblies at runtime.
- **Unit test execution**  
  Test executables often use `APP_LIB_DIR` as their working directory so that all required libraries are immediately available without additional copying.
- **Default behavior**  
  If `APP_LIB_DIR` is not explicitly set, the default will be the build directory. This usually works for quick builds, but is not recommended for larger projects where predictable probing paths and manifests are required.

## Usage

### Source File Filtering
```cmake
add_files(${PROJECT_NAME} RECURSE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_sources(my_target PRIVATE ${SOURCE_FILES})
```

### Application Manifests

`gen_manifest_app(target version dependencies...)` uses the target's runtime output directory.
An explicit `OUTPUT_DIRECTORY` also allows generation from a `cmake -P` script without defining a project or target:

```cmake
set(MANIFEST_PROCESSOR_ARCHITECTURE amd64)
gen_manifest_app(my_app 1.2.3 OUTPUT_DIRECTORY "C:/package" libexample:1.0)
```

The manifest identity uses the supplied package name and version. Other application metadata is read from `PROJECT_DESCRIPTION` and `APP_NAME` when provided.

### Runtime DLL Manifests (Windows)

`runtime.cmake` provides `gen_runtime_manifests()` for use after linking, including from `cmake -P`:

```cmake
set(TEMPLATES_DIR "${ACBT_DIR}/templates")
set(MANIFEST_PROCESSOR_ARCHITECTURE amd64)
include("${ACBT_DIR}/runtime.cmake")
gen_runtime_manifests(
    EXECUTABLE "C:/package/my_app.exe"
    NAME my_app VERSION 1.2.3
    OUTPUT_DIRECTORY "C:/package"
    LIBRARY_DIRECTORY "C:/package/lib/Windows"
    DIRECTORIES "C:/toolchain/bin"
    LOCAL_LIBRARIES libmy_library.dll
    VERSIONS "libmy_library.dll:1.2.3")
```

The function recursively reads PE import tables using `llvm-objdump` or `objdump`
(`OBJDUMP` can specify its path), excludes Windows system imports, and calls
`gen_manifest_lib()` and `gen_manifest_app()` with each binary's direct dependencies.
Missing non-system imports stop generation. No DLLs are loaded or copied.

`LOCAL_LIBRARIES` selects binaries from `LIBRARY_DIRECTORY` before `DIRECTORIES`;
other binaries are searched in the reverse order. Versions explicitly supplied in
`VERSIONS` take precedence over `get_windows_dll_file_version()`. DLLs without a
numeric FileVersion receive a stable assembly identity derived from their SHA-256
bytes; this identity is not a software release version.

`get_windows_dll_file_version(path result OPTIONAL)` returns an empty result when
no numeric FileVersion is present. Without `OPTIONAL`, that remains an error.

### Unit Test Generation
```cmake
set(TEST_LIBRARIES ${COMMON_LIBRARIES})
set(TEST_ENV ${ENV_VARIABLES})
set(TEST_SOURCES ${COMMON_SOURCES})

add_test_files(LABEL A a.cpp)
add_test_files(LABEL B b.cpp)
add_test_files(LABEL N n.cpp)
add_test_coverage(LABEL)
```

## License
This project is licensed under the [MIT License](LICENSE).

## Contacts
For any questions or feedback, you can reach out via [email](mailto:wusikijeronii@gmail.com) or open a new issue.