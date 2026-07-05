#!/usr/bin/env python3
"""nest — C++ CMake wrapper CLI."""

import argparse
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, NoReturn

# ── Constants ────────────────────────────────────────────────────────────────

_HERE = pathlib.Path(__file__).resolve().parent
_TEMPLATES_DIR = _HERE / "templates"


# ── ANSI ─────────────────────────────────────────────────────────────────────


def _init_ansi() -> dict[str, str]:
    if not sys.stdout.isatty():
        return {
            "red": "",
            "green": "",
            "yellow": "",
            "cyan": "",
            "bold": "",
            "reset": "",
        }
    return {
        "red": "\033[31m",
        "green": "\033[32m",
        "yellow": "\033[33m",
        "cyan": "\033[36m",
        "bold": "\033[1m",
        "reset": "\033[0m",
    }


_STYLE = _init_ansi()


def _cyan(text: Any) -> str:
    return f"{_STYLE['cyan']}{text}{_STYLE['reset']}"


def _green(text: Any) -> str:
    return f"{_STYLE['green']}{text}{_STYLE['reset']}"


def _yellow(text: Any) -> str:
    return f"{_STYLE['yellow']}{text}{_STYLE['reset']}"


def _red(text: Any) -> str:
    return f"{_STYLE['red']}{text}{_STYLE['reset']}"


def _bold(text: Any) -> str:
    return f"{_STYLE['bold']}{text}{_STYLE['reset']}"


def _info(msg: str) -> None:
    print(f"  {_cyan('·')} {msg}", flush=True)


def _ok(msg: str) -> None:
    print(f"  {_green('✔')}  {msg}", flush=True)


def _warn(msg: str) -> None:
    print(f"  {_yellow('⚠')}  {msg}", flush=True)


def _err(msg: str) -> None:
    print(f"  {_red('✘')}  {msg}", file=sys.stderr, flush=True)


def _error_exit(msg: str, code: int = 1) -> NoReturn:
    _err(msg)
    sys.exit(code)


# ── Paths ────────────────────────────────────────────────────────────────────


@dataclass
class _BinaryInfo:
    version: str
    build_type: str
    path: pathlib.Path


def _find_root() -> pathlib.Path | None:
    cwd = pathlib.Path.cwd().resolve()
    for parent in [cwd, *cwd.parents]:
        if (parent / "CMakeLists.txt").exists() and (parent / "cmake" / "nest.cmake").exists():
            return parent
    return None


_found_root = _find_root()
ROOT = _found_root if _found_root is not None else pathlib.Path.cwd().resolve()
NEST_DIR = ROOT / ".nest"
BUILD_DIR = NEST_DIR / "build"
PROJECTS_DIR = ROOT / "projects"
TESTS_DIR = ROOT / "tests"
CONFIG_FILE = NEST_DIR / "config.json"


# ── Utilities ────────────────────────────────────────────────────────────────


def _num_cpus() -> int:
    try:
        return len(os.sched_getaffinity(0))
    except AttributeError:
        return os.cpu_count() or 4


def _require_cmd(name: str) -> None:
    if not shutil.which(name):
        _error_exit(f"{name} not found on PATH")


def _run_or_exit(
    cmd: list[str],
    msg: str,
    cwd: pathlib.Path = ROOT,
    **kwargs,
) -> subprocess.CompletedProcess:
    _require_cmd(cmd[0])
    result = subprocess.run(cmd, cwd=cwd, check=False, **kwargs)
    if result.returncode != 0:
        print(f"  $ {shlex.join(cmd)}", file=sys.stderr)
        _error_exit(msg, code=result.returncode)
    return result


def _read_json(path: pathlib.Path) -> dict[str, Any]:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            _warn(f"Invalid JSON in {path}")
    return {}


def _write_json(path: pathlib.Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=4) + "\n")


# ── Version ──────────────────────────────────────────────────────────────────


def _get_version() -> str:
    cmake = ROOT / "CMakeLists.txt"
    if cmake.exists():
        m = re.search(
            r"nest_VERSION\s*\(\s*(\d+)\s+(\d+)\s+(\d+)\s*\)",
            cmake.read_text(),
        )
        if m:
            return f"{m.group(1)}.{m.group(2)}.{m.group(3)}"
    return "0.0.0"


# ── Project Discovery ───────────────────────────────────────────────────────


def _get_projects() -> list[str]:
    if not PROJECTS_DIR.is_dir():
        return []
    return sorted(
        d.name
        for d in PROJECTS_DIR.iterdir()
        if d.is_dir() and not d.name.startswith(".") and (d / "CMakeLists.txt").exists()
    )


def _get_tests() -> list[str]:
    if not TESTS_DIR.is_dir():
        return []
    return sorted(f.stem for f in TESTS_DIR.glob("*.cpp"))


def _get_presets() -> list[str]:
    data = _read_json(ROOT / "CMakePresets.json")
    return [p["name"] for p in data.get("configurePresets", []) if not p.get("hidden", False)]


# ── Preset Management ────────────────────────────────────────────────────────


def _get_default_preset() -> str:
    config = _read_json(CONFIG_FILE)
    return config.get("default_preset", "debug")


def _set_default_preset(name: str) -> None:
    config = _read_json(CONFIG_FILE)
    config["default_preset"] = name
    _write_json(CONFIG_FILE, config)
    _ok(f"Default preset set to '{name}'")


def _resolve_preset(args: argparse.Namespace) -> str:
    if args.preset:
        return args.preset
    if args.release:
        return "release"
    if args.debug:
        return "debug"
    return _get_default_preset()


# ── Argparse Helpers ─────────────────────────────────────────────────────────


def _add_preset_args(parser: argparse.ArgumentParser) -> None:
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-p", "--preset", help="Build preset")
    group.add_argument("--release", action="store_true", help="Shortcut for --preset release")
    group.add_argument("--debug", action="store_true", help="Shortcut for --preset debug")


def _add_target_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "targets",
        nargs="*",
        default=None,
        help="Target(s) to build (default: all)",
    )


# ── Build System ─────────────────────────────────────────────────────────────


def _configure(preset: str, verbose: bool = False) -> None:
    _info(f"Configuring (preset: {preset})")
    cmd = ["cmake", "--preset", preset, "-G", "Ninja"]
    if verbose:
        _info(f"$ {shlex.join(cmd)}")
    _run_or_exit(cmd, "Configure failed")
    src = BUILD_DIR / "compile_commands.json"
    dst = ROOT / "compile_commands.json"
    if src.exists():
        shutil.copy2(src, dst)
    _ok("Configured")


def _build(targets: list[str] | None, preset: str, verbose: bool = False) -> None:
    if not BUILD_DIR.exists():
        _configure(preset, verbose=verbose)
    jobs = _num_cpus()
    cmd = ["cmake", "--build", str(BUILD_DIR), "-j", str(jobs)]
    if targets:
        cmd.extend(["--target", *targets])
    label = "all" if not targets else ", ".join(targets)
    _info(f"Building {label} ({preset})")
    if verbose:
        _info(f"$ {shlex.join(cmd)}")
    _run_or_exit(cmd, "Build failed")
    _ok("Build complete")


# ── Binary Discovery ─────────────────────────────────────────────────────────


def _find_binaries(target: str) -> list[_BinaryInfo]:
    base = NEST_DIR / "bin" / target
    if not base.is_dir():
        return []
    results: list[_BinaryInfo] = []
    for vdir in sorted(base.iterdir()):
        if not vdir.is_dir() or not vdir.name.startswith("v"):
            continue
        for bdir in sorted(vdir.iterdir()):
            if not bdir.is_dir():
                continue
            binary = bdir / target
            if binary.exists() and binary.is_file() and os.access(binary, os.X_OK):
                results.append(_BinaryInfo(vdir.name, bdir.name, binary))
    return results


def _interactive_select(options: list[str], prompt: str = "Choose > ") -> str | None:
    if not options:
        return None
    if len(options) == 1:
        return options[0]
    fzf_path = shutil.which("fzf")
    if fzf_path is not None:
        try:
            result = subprocess.run(
                [fzf_path, "-1", f"--prompt={prompt}", "--layout=reverse", "--cycle"],
                input="\n".join(options),
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except (FileNotFoundError, OSError):
            pass
    print()
    for i, opt in enumerate(options, 1):
        print(f"  {_cyan(i)}. {opt}")
    while True:
        try:
            choice = input(f"  {prompt} (1-{len(options)}): ").strip()
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                return options[idx]
        except (ValueError, EOFError):
            pass
        print(f"  Invalid. Enter 1-{len(options)}.")


# ── Interactive runner ───────────────────────────────────────────────────────


def _pick_binary(target: str) -> pathlib.Path:
    binaries = _find_binaries(target)
    if not binaries:
        _error_exit(f"No built binary found for '{target}'")
    if len(binaries) == 1:
        return binaries[0].path
    versions = sorted({b.version for b in binaries}, reverse=True)
    chosen = _interactive_select(versions, "Choose version > ")
    if not chosen:
        _error_exit("Selection cancelled")
    subset = [b for b in binaries if b.version == chosen]
    if len(subset) == 1:
        return subset[0].path
    build_types = sorted({b.build_type for b in subset})
    chosen_build = _interactive_select(build_types, "Choose configuration > ")
    if not chosen_build:
        _error_exit("Selection cancelled")
    return next(b.path for b in subset if b.build_type == chosen_build)


# ── Scaffolding ──────────────────────────────────────────────────────────────


def _scaffold(name: str, type_: str) -> None:
    target_dir = PROJECTS_DIR / name
    if target_dir.exists():
        _error_exit(f"Directory '{name}' already exists")
    target_dir.mkdir(parents=True)
    if type_ == "exe":
        (target_dir / "CMakeLists.txt").write_text(
            "nest_VERSION(0 0 1)\nnest_SETUP_EXE()\n# nest_LINK(foo bar)\n",
        )
        (target_dir / "main.cpp").write_text(
            "#include <cstdio>\n\n" "int main() {\n" f'    std::puts("Hello from {name}!");\n' "    return 0;\n" "}\n",
        )
        _ok(f"Created executable '{name}'")
    else:
        lib_type = type_.upper()
        (target_dir / "CMakeLists.txt").write_text(
            f"nest_VERSION(0 0 1)\nnest_SETUP_LIB({lib_type})\n# nest_LINK(foo bar)\n",
        )
        header = "#pragma once\n\n"
        if lib_type == "SHARED":
            header += f'#include "{name}_export.h"\n\n'
        (target_dir / f"{name}.hpp").write_text(header)
        (target_dir / f"{name}.cpp").write_text(f'#include "{name}.hpp"\n')
        _ok(f"Created {lib_type} library '{name}'")


# ── Command Handlers ─────────────────────────────────────────────────────────


def _cmd_list(_: argparse.Namespace) -> None:
    projects = _get_projects()
    tests = _get_tests()
    presets = _get_presets()
    default = _get_default_preset()
    print(f"\n  {_bold('Projects')}")
    if projects:
        for p in projects:
            print(f"    {_cyan(p)}")
    else:
        print("    (none)")
    print(f"\n  {_bold('Tests')}")
    if tests:
        for t in tests:
            print(f"    {_cyan(t)}")
    else:
        print("    (none)")
    print(f"\n  {_bold('Presets')}")
    if presets:
        for p in presets:
            mark = f" {_green('(default)')}" if p == default else ""
            print(f"    {_cyan(p)}{mark}")
    else:
        print("    (none)")
    print()


def _cmd_build(args: argparse.Namespace) -> None:
    _build(args.targets, _resolve_preset(args), verbose=args.verbose)


def _cmd_run(args: argparse.Namespace) -> None:
    if args.target is None:
        projects = _get_projects()
        if not projects:
            _error_exit("No projects found to run")
        chosen = _interactive_select(projects, "Choose target > ")
        if not chosen:
            _error_exit("Selection cancelled")
        args.target = chosen
    preset = _resolve_preset(args)
    _build([args.target], preset, verbose=args.verbose)
    binary = _pick_binary(args.target)
    _info(f"Running {_bold(binary.name)} {' '.join(args.args) if args.args else ''}")
    result = subprocess.run([str(binary), *args.args])
    sys.exit(result.returncode)


def _cmd_test(args: argparse.Namespace) -> None:
    preset = _resolve_preset(args)
    test_names = args.tests
    if test_names:
        _build(test_names, preset, verbose=args.verbose)
    else:
        tests = _get_tests()
        if tests:
            _build(tests, preset, verbose=args.verbose)
    jobs = _num_cpus()
    cmd: list[str] = [
        "ctest",
        "--test-dir",
        str(BUILD_DIR),
        "--output-on-failure",
        "--parallel",
        str(jobs),
        "-C",
        preset,
    ]
    if args.verbose:
        cmd.append("--verbose")
    if test_names:
        cmd.extend(["-R", "^(" + "|".join(test_names) + ")$"])
    _info("Running tests")
    if args.verbose:
        _info(f"$ {shlex.join(cmd)}")
    _run_or_exit(cmd, "Some tests failed")
    _ok("All tests passed")


def _cmd_new(args: argparse.Namespace) -> None:
    _scaffold(args.name, args.type)


def _cmd_clean(args: argparse.Namespace) -> None:
    if args.all:
        if NEST_DIR.exists():
            shutil.rmtree(NEST_DIR)
            _ok("Removed .nest/")
        compile_db = ROOT / "compile_commands.json"
        if compile_db.exists():
            compile_db.unlink()
            _ok("Removed compile_commands.json")
    else:
        for subdir in [BUILD_DIR, NEST_DIR / "lib", NEST_DIR / "bin"]:
            if subdir.exists():
                shutil.rmtree(subdir)
                _ok(f"Cleaned {subdir.relative_to(ROOT)}/")
    _ok("Clean complete")


def _cmd_preset_list(_: argparse.Namespace) -> None:
    presets = _get_presets()
    default = _get_default_preset()
    print()
    for p in presets:
        mark = f" {_green('(default)')}" if p == default else ""
        print(f"  {_cyan(p)}{mark}")
    print()


def _cmd_preset_set(args: argparse.Namespace) -> None:
    presets = _get_presets()
    if args.name not in presets:
        _error_exit(f"Unknown preset '{args.name}'. Available: {', '.join(presets)}")
    _set_default_preset(args.name)


# ── Init Helpers ─────────────────────────────────────────────────────────────


_GITIGNORE_BLOCK = """\
.nest/
Testing/
Makefile
CMakeFiles/
CMakeScripts/
CMakeCache.txt
cmake_install.cmake
install_manifest.txt
compile_commands.json
*.o
*.obj
*.a
*.lib
*.so
*.dylib
*.dll
*.exe
*.out
.DS_Store
"""


def _init_try_copy(src: pathlib.Path, dst: pathlib.Path) -> None:
    if dst.exists():
        _warn(f"Skipped {dst.name} \u2014 already exists")
    else:
        shutil.copy2(src, dst)
        _ok(f"Created {dst.name}")


def _init_try_write(dst: pathlib.Path, content: str) -> None:
    if dst.exists():
        _warn(f"Skipped {dst.name} \u2014 already exists")
    else:
        dst.write_text(content)
        _ok(f"Created {dst.name}")


def _init_gitignore(dst: pathlib.Path) -> None:
    if dst.exists():
        content = dst.read_text()
        if ".nest/" in content:
            _warn("Skipped .gitignore \u2014 already has .nest/ entry")
            return
        dst.write_text(content.rstrip() + "\n\n" + _GITIGNORE_BLOCK)
        _ok("Extended .gitignore with NEST entries")
    else:
        dst.write_text(_GITIGNORE_BLOCK)
        _ok("Created .gitignore")


def _cmd_init(args: argparse.Namespace) -> None:
    target = ROOT

    name = target.name
    if args.name:
        name = args.name
    elif args.interactive:
        print(f"  Project name [{name}]: ", end="", flush=True)
        inp = input().strip()
        if inp:
            name = inp

    for d in ["cmake", "projects", "tests", "vendor"]:
        (target / d).mkdir(exist_ok=True)

    for t in sorted(_TEMPLATES_DIR.iterdir()):
        if t.name in ("nest.cmake", "nestConfig.cmake.in"):
            _init_try_copy(t, target / "cmake" / t.name)
        else:
            _init_try_copy(t, target / t.name)

    cmake_content = f"""cmake_minimum_required(VERSION 3.28)
include(cmake/nest.cmake)
project({name})

nest_VERSION(0 0 1)
nest_INIT(20)

nest_DETECT_PROJECTS()
nest_ENABLE_TESTS()
nest_GENERATE_EXPORT()
"""
    _init_try_write(target / "CMakeLists.txt", cmake_content)

    _init_gitignore(target / ".gitignore")

    config_dir = target / ".nest"
    config_dir.mkdir(exist_ok=True)
    _init_try_write(config_dir / "config.json", json.dumps({"default_preset": "debug"}, indent=4) + "\n")

    _ok(f"Nest project '{name}' initialized")


# ── Main ─────────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="nest",
        description="C++ CMake wrapper build tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
examples:"""
        + "\n  "
        + "\n  ".join(
            f"{cmd:<28s} {desc}"
            for cmd, desc in [
                ("nest", "list projects, tests, presets"),
                ("nest init", "initialize a Nest project in current directory"),
                ("nest init -n myproj", "with explicit project name"),
                ("nest init -i", "prompt to confirm project name"),
                ("nest build", "build all projects"),
                ("nest build -v", "build with verbose cmake output"),
                ("nest build myapp", "build specific target"),
                ("nest build --release", "build with release preset"),
                ("nest run", "pick target interactively, build & run"),
                ("nest run myapp", "build and run"),
                ("nest run myapp -- --arg1", "pass arguments to target"),
                ("nest test", "build and run all tests"),
                ("nest test -v", "with verbose output"),
                ("nest test test_math test_y", "specific tests"),
                ("nest new myapp", "create new executable"),
                ("nest new mylib -t static", "create new static library"),
                ("nest preset list", "show presets"),
                ("nest preset set release", "change default preset"),
                ("nest clean", "clean build artifacts"),
                ("nest clean --all", "full clean (removes .nest/)"),
            ]
        )
        + "\n",
    )
    parser.add_argument("--version", action="version", version=f"nest {_get_version()}")

    sub = parser.add_subparsers(dest="command", title="commands")

    p_list = sub.add_parser("list", help="List projects, tests, and presets")
    p_list.set_defaults(func=_cmd_list)

    p_init = sub.add_parser("init", help="Initialize a Nest project in the current directory")
    p_init.add_argument("-n", "--name", help="Project name (default: directory name)")
    p_init.add_argument("-i", "--interactive", action="store_true", help="Prompt to confirm or change project name")
    p_init.set_defaults(func=_cmd_init)

    p_build = sub.add_parser("build", help="Build targets")
    _add_target_args(p_build)
    _add_preset_args(p_build)
    p_build.add_argument("-v", "--verbose", action="store_true", help="Print raw cmake commands")
    p_build.set_defaults(func=_cmd_build)

    p_run = sub.add_parser("run", help="Build and run a target")
    p_run.add_argument("target", nargs="?", default=None, help="Target to run (omit to pick interactively)")
    p_run.add_argument("args", nargs="*", help="Arguments to pass to target")
    _add_preset_args(p_run)
    p_run.add_argument("-v", "--verbose", action="store_true", help="Print raw cmake commands")
    p_run.set_defaults(func=_cmd_run)

    p_test = sub.add_parser("test", help="Build and run tests")
    p_test.add_argument("tests", nargs="*", default=None, help="Specific tests (default: all)")
    _add_preset_args(p_test)
    p_test.add_argument("-v", "--verbose", action="store_true", help="Print raw commands")
    p_test.set_defaults(func=_cmd_test)

    p_new = sub.add_parser("new", help="Scaffold a new project")
    p_new.add_argument("name", help="Project name")
    p_new.add_argument(
        "-t",
        "--type",
        choices=["exe", "shared", "static"],
        default="exe",
        help="Project type",
    )
    p_new.set_defaults(func=_cmd_new)

    p_clean = sub.add_parser("clean", help="Clean build artifacts")
    p_clean.add_argument("--all", action="store_true", help="Remove .nest/ entirely")
    p_clean.set_defaults(func=_cmd_clean)

    p_preset = sub.add_parser("preset", help="Manage build presets")
    p_preset_sub = p_preset.add_subparsers(dest="action", required=True)
    p_preset_list = p_preset_sub.add_parser("list", help="List available presets")
    p_preset_list.set_defaults(func=_cmd_preset_list)
    p_preset_set = p_preset_sub.add_parser("set", help="Set default preset")
    p_preset_set.add_argument("name", help="Preset name")
    p_preset_set.set_defaults(func=_cmd_preset_set)

    args = parser.parse_args()

    if args.command == "init":
        global ROOT, NEST_DIR, BUILD_DIR, PROJECTS_DIR, TESTS_DIR, CONFIG_FILE
        ROOT = pathlib.Path.cwd().resolve()
        NEST_DIR = ROOT / ".nest"
        BUILD_DIR = NEST_DIR / "build"
        PROJECTS_DIR = ROOT / "projects"
        TESTS_DIR = ROOT / "tests"
        CONFIG_FILE = NEST_DIR / "config.json"
        _cmd_init(args)
        return

    if _found_root is None:
        _error_exit("not inside a Nest project (no CMakeLists.txt with cmake/nest.cmake found)")

    if args.command is None:
        _cmd_list(args)
    else:
        args.func(args)


if __name__ == "__main__":
    main()
