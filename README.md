# Eel Pool

Eel Pool is a code name for a game project. When the project evolves enough to
develop its own identity, it will be renamed to something more fitting.

## Build

Install [mise](https://mise.jdx.dev/getting-started.html) to manage tools and environment.

Then use the build script for different targets:

```bash
-release                     | Produce a release build
-dev                         | Produce a development build
-gamelib                     | Build the game code as a dynamic library
```

Or use the build script with various options:

```bash
-clean                       | Clean the build directory
-check                       | Check for compilation errors and successful initialization
-test                        | Build and run all test functions
-docs                        | Generate documentation
-run                         | Run the targets after building
-run-arg:<string>, multiple  | Arguments passed to the app when run enabled
-run-env:<string>, multiple  | Environment passed to the app when run enabled
-verbose                     | Enable verbose output
-debug                       | Enable debug mode
```

Examples:

```bash
# Display all options
mise build -help

# Clean the build directory before building
mise build -clean -dev

# Run tests with verbose output
mise build -test -verbose

# Build and run a dev build for 60 frames
mise build -dev -run -run-arg:"-run-for:60"
```
