# How to build the CMake find_package example
## Requirements
You will first need to install the switch-ruby library on your system.
```bash
# in the root folder
cmake -B build
cmake --build build
cmake --install build
```

# Build
```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE:FILEPATH=common/DevkitA64Libnx.cmake .
cmake --build build
```

This will produce the NRO at `build/ruby_app.nro`.