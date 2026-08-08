cmake_minimum_required(VERSION 3.20)
project(gitpulse-tray LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

qt_add_executable(gitpulse-tray main.cpp)
target_link_libraries(gitpulse-tray PRIVATE Qt6::Widgets)
target_compile_features(gitpulse-tray PRIVATE cxx_std_17)

install(TARGETS gitpulse-tray RUNTIME DESTINATION bin)
