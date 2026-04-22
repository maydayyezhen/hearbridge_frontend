cmake_minimum_required(VERSION 3.5.0)
project(hand_detector)

add_library(entry SHARED hand_detector.cpp)

target_link_libraries(entry PUBLIC libace_napi.z.so libhilog_ndk.z.so)