# Eel Pool

Eel Pool is a code name for a game project. When the project evolves enough to
develop its own identity, it will be renamed to something more fitting.

## Build

First, build the build script:

```bash
odin build build.odin -file
```

Then use the build script for different targets:

```bash
-all      | Build all targets
-release  | Produce a release build
-develop  | Produce a development build
-test     | Build and run all test functions
```

Common examples:

```bash
# Clean the build directory before building all targets
./build -clean -all

# Run tests with verbose output
./build -test -verbose

# Display all options
./build -help
```
