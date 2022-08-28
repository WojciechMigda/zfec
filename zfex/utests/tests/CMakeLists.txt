# rapidcheck:
# https://github.com/WojciechMigda/zfex/raw/rapidcheck/rapidcheck.zip
#
# boost.ut
# https://github.com/WojciechMigda/zfex/raw/boost.ut/boost-ut.zip

add_subdirectory( rapidcheck )

function(add_ut)
    set( options TEST_NAME )
    set( oneValueArgs EXE_NAME SOURCE )
    set( multiValueArgs EXT_LIBS )
    cmake_parse_arguments( parsed "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    if( parsed_UNPARSED_ARGUMENTS )
        message( FATAL_ERROR "[add_ut] Bad arguments: ${parsed_UNPARSED_ARGUMENTS}" )
    endif()

    if( NOT parsed_TEST_NAME )
        set( parsed_TEST_NAME ${parsed_EXE_NAME} )
    endif()

    add_executable( ${parsed_EXE_NAME} "src/dummy.cpp" )
    target_sources( ${parsed_EXE_NAME} PRIVATE ${parsed_SOURCE} )
    target_include_directories( ${parsed_EXE_NAME} PRIVATE ${CMAKE_CURRENT_LIST_DIR}/include ${CMAKE_SOURCE_DIR}/.. )
    target_link_libraries( ${parsed_EXE_NAME} zfex ${parsed_EXT_LIBS} )
    add_test( ${parsed_TEST_NAME} ${parsed_EXE_NAME} )
endfunction()

# the most time consuming tests go first
add_ut( EXE_NAME test_encode_decode         SOURCE "src/test_encode_decode.cpp" EXT_LIBS rapidcheck )
