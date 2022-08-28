cmake_minimum_required( VERSION 3.5 )

project( zfex_utests VERSION 1.0.0 LANGUAGES C CXX )

set( CMAKE_POSITION_INDEPENDENT_CODE ON )

################################################################################

set( CMAKE_CXX_STANDARD 17 )

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

################################################################################

add_library( zfex STATIC dummy.c )
target_sources( zfex PRIVATE ../zfex.c )

target_include_directories( zfex PRIVATE ${CMAKE_CURRENT_LIST_DIR}/.. )

target_compile_options( zfex PRIVATE "-std=c99" )

#target_compile_features(tsetlini_ObjLib PRIVATE cxx_rvalue_references)

################################################################################

enable_testing()
add_subdirectory(tests)
