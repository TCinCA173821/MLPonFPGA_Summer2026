# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
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
# ====================================================================================
set(PICO_BOARD pico CACHE STRING "Board type")

cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico_to_fpga C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(pico_to_fpga
    source/main.c
    source/weights.c
    source/form_packet.c
    source/send_packet.c
    source/usb_image.c
    source/handshake.c
    source/bus_clock.c
)

target_include_directories(pico_to_fpga PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/source
)

target_link_libraries(pico_to_fpga
    pico_stdlib
)

pico_enable_stdio_usb(pico_to_fpga 1)
pico_enable_stdio_uart(pico_to_fpga 0)

pico_add_extra_outputs(pico_to_fpga)
