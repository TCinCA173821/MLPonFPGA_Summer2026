# Use the same locally installed SDK/toolchain selected by the Pico VS Code
# extension for the main firmware project.
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.3.0)
set(toolchainVersion 15_2_Rel1)
set(picotoolVersion 2.3.0)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()

cmake_minimum_required(VERSION 3.13)

include(../pico_sdk_import.cmake)

project(cs_nxt_test C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(cs_nxt_test
    main.c
)

target_link_libraries(cs_nxt_test
    pico_stdlib
)

pico_enable_stdio_usb(cs_nxt_test 1)
pico_enable_stdio_uart(cs_nxt_test 0)
pico_add_extra_outputs(cs_nxt_test)
