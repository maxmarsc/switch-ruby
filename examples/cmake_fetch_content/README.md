# How to build the CMake FetchContent example
```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE:FILEPATH=common/DevkitA64Libnx.cmake .
cmake --build build
```

This will produce the NRO at `build/ruby_app.nro`.