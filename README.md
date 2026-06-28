# NEST
C++ CMake Wrapper

## Quick Start

```bash
# Install the CLI (one-time)
uv tool install ./cli

# Or run directly without installing
python cli/nest.py build

# List projects, tests, presets
nest

# Build and run
nest build
nest build myapp
nest run myapp

# Test
nest test
nest test --verbose
nest test test_y_math test_y_string

# Scaffold new projects
nest new myapp
nest new mylib -t static
nest new mylib -t shared

# Presets
nest preset list
nest preset set release
nest build --release

# Clean
nest clean
nest clean --all
```

Output goes to `.nest/bin/<target>/v<version>/<config>/<target>`.

## With just (legacy)

`just` is still available as a fallback for the original workflow.
