cmake_minimum_required(VERSION 3.20)

project(MSBASIC-RP6502 ASM)

add_subdirectory(tools)

add_executable(basic)
rp6502_asset(basic help src/help.txt)
rp6502_executable(basic DATA 0xC000 RESET 0xC000)

target_link_options(basic PRIVATE
    -C ${CMAKE_CURRENT_SOURCE_DIR}/src/rp6502.cfg
)

set_target_properties(basic PROPERTIES
    LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/rp6502.cfg
)

target_include_directories(basic PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/mist64
)

target_sources(basic PRIVATE
    src/msbasic.s
)
