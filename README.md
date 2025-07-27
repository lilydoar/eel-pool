# Eel Pool

## Build

First, build the build script:

```bash
odin build build.odin -file
```

Then use the build script for different targets:

```bash
# Development build with hot reload support
./build -develop

# Release build with static linking
./build -release

# Game logic as a dynamic library (for hot reloading)
./build -gamelib

# Clean the build directory before building
./build -clean

# Enable verbose output
./build -verbose
```
