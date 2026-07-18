cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico_to_fpga C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(pico_to_fpga
    src/main.c
    src/weights.c
    src/form_packet.c
    src/send_packet.c
    src/usb_image.c
    src/handshake.c
    src/bus_clock.c
)

target_include_directories(pico_to_fpga PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/src
)

target_link_libraries(pico_to_fpga
    pico_stdlib
)

pico_enable_stdio_usb(pico_to_fpga 1)
pico_enable_stdio_uart(pico_to_fpga 0)

pico_add_extra_outputs(pico_to_fpga)
