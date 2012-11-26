
CMAKE_MINIMUM_REQUIRED(VERSION 2.6 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.6)
FIND_PACKAGE(Torch REQUIRED)

SET(luasrc init.lua 
    utils.lua
    test.lua)

ADD_TORCH_PACKAGE(graph ""  "${luasrc}" "General Graph Package")
