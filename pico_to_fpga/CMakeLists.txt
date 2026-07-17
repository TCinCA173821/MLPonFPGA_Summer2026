cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico_fpga_bus C CXX ASM)

pico_sdk_init()

add_executable(pico_fpga_bus
    source/main.c
    source/weights.c
    source/form_packet.c
    source/send_packet.c
    source/bus_clock.c
    source/handshake.c
    source/usb_image.c
)

target_include_directories(pico_fpga_bus PRIVATE
    source
)

target_link_libraries(pico_fpga_bus
    pico_stdlib
    hardware_gpio
)

pico_enable_stdio_usb(pico_fpga_bus 1)
pico_enable_stdio_uart(pico_fpga_bus 0)

pico_add_extra_outputs(pico_fpga_bus)
