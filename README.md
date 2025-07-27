# Eel Pool

## Build

First, build the build script:

```bash
odin build build.odin -file
```

Then use the build script for different targets:

```bash
-all      | Build all targets
-clean    | Clean the build directory before building
-develop  | Produce a development build
-gamelib  | Build the game code as a dynamic library
-release  | Produce a release build
-test     | Build and run all test functions
```

Common examples:

```bash
# Build all targets
./build -all

# Clean the build directory before building a release
./build -clean -release

# Run tests with verbose output
./build -test -verbose

# Display all options
./build -help
```
