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

## Usage

### Source File Filtering
```cmake
add_files(${PROJECT_NAME} RECURSE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_sources(my_target PRIVATE ${SOURCE_FILES})
```

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