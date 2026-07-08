cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(pico_fpga_bus C CXX ASM)

pico_sdk_init()

add_executable(pico_fpga_bus
    src/main.c
    src/parallel_bus.c
)

target_include_directories(pico_fpga_bus PRIVATE
    src
)

target_link_libraries(pico_fpga_bus
    pico_stdlib
    hardware_gpio
)

pico_enable_stdio_usb(pico_fpga_bus 1)
pico_enable_stdio_uart(pico_fpga_bus 0)

pico_add_extra_outputs(pico_fpga_bus)