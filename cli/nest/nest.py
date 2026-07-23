#!/usr/bin/env python3
"""nest — C++ CMake wrapper CLI."""

import argparse
import json
import os
import pathlib
import re
import shlex
import shutil
import string
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, NoReturn

# --- Constants ----------------------------------------------------------------

PKG_PATH = pathlib.Path(__file__).resolve().parent
TEMPLATES_DIR = PKG_PATH / "templates"


# --- ANSI --------------------------------------------------------------------


class TermColor:
    def __init__(self) -> None:
        if sys.stdout.isatty():
            self._red = "\033[31m"
            self._green = "\033[32m"
            self._yellow = "\033[33m"
            self._cyan = "\033[36m"
            self._bold = "\033[1m"
            self._reset = "\033[0m"
        else:
            self._red = self._green = self._yellow = ""
            self._cyan = self._bold = self._reset = ""

    def cyan(self, text: Any) -> str:
        return f"{self._cyan}{text}{self._reset}"

    def green(self, text: Any) -> str:
        return f"{self._green}{text}{self._reset}"

    def yellow(self, text: Any) -> str:
        return f"{self._yellow}{text}{self._reset}"

    def red(self, text: Any) -> str:
        return f"{self._red}{text}{self._reset}"

    def bold(self, text: Any) -> str:
        return f"{self._bold}{text}{self._reset}"


t = TermColor()


class Logger:
    def info(self, msg: str) -> None:
        print(f"  {t.cyan('·')} {msg}", flush=True)

    def ok(self, msg: str) -> None:
        print(f"  {t.green('✔')}  {msg}", flush=True)

    def warn(self, msg: str) -> None:
        print(f"  {t.yellow('⚠')}  {msg}", flush=True)

    def err(self, msg: str) -> None:
        print(f"  {t.red('✘')}  {msg}", file=sys.stderr, flush=True)

    def exit(self, msg: str, code: int = 1) -> NoReturn:
        self.err(msg)
        sys.exit(code)


log = Logger()


# --- Paths -------------------------------------------------------------------


@dataclass
class BinaryInfo:
    version: str
    build_type: str
    path: pathlib.Path


def root_find() -> pathlib.Path | None:
    cwd = pathlib.Path.cwd().resolve()
    for parent in [cwd, *cwd.parents]:
        if (parent / "CMakeLists.txt").exists() and (
            parent / "cmake" / "nest.cmake"
        ).exists():
            return parent
    return None


_found_root = root_find()
ROOT = _found_root if _found_root is not None else pathlib.Path.cwd().resolve()
NEST_DIR = ROOT / ".nest"
BUILD_DIR = NEST_DIR / "build"
PROJECTS_DIR = ROOT / "projects"
TESTS_DIR = ROOT / "tests"
CONFIG_FILE = NEST_DIR / "config.json"


# --- Helpers -----------------------------------------------------------------


def _cpu_count() -> int:
    try:
        return len(os.sched_getaffinity(0))
    except AttributeError:
        return os.cpu_count() or 4


def run_or_exit(
    cmd: list[str],
    msg: str,
    cwd: pathlib.Path = ROOT,
    **kwargs,
) -> subprocess.CompletedProcess:

    if not shutil.which(cmd[0]):
        log.exit(f"{cmd[0]} not found on PATH")

    result = subprocess.run(cmd, cwd=cwd, check=False, **kwargs)
    if result.returncode != 0:
        print(f"  $ {shlex.join(cmd)}", file=sys.stderr)
        log.exit(msg, code=result.returncode)

    return result


def json_read(path: pathlib.Path) -> dict[str, Any]:
    if not path.exists():
        return {}

    try:
        return json.loads(path.read_text())

    except Exception as err:
        log.warn(f"Invalid JSON in {path} : {err}")
        return {}


def json_write(path: pathlib.Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=4) + "\n")


# --- Version -----------------------------------------------------------------


def version_get() -> str:
    cmake = ROOT / "CMakeLists.txt"

    if not cmake.exists():
        return "0.0.0"

    m = re.search(
        r"nest_VERSION\s*\(\s*(\d+)\s+(\d+)\s+(\d+)\s*\)",
        cmake.read_text(),
    )

    if m:
        return f"{m.group(1)}.{m.group(2)}.{m.group(3)}"

    return "0.0.0"


# --- Project Discovery ------------------------------------------------------


def existing_projects() -> list[str]:
    if not PROJECTS_DIR.is_dir():
        return []

    return sorted(
        d.name
        for d in PROJECTS_DIR.iterdir()
        if d.is_dir() and not d.name.startswith(".") and (d / "CMakeLists.txt").exists()
    )


def existing_tests() -> list[str]:
    if not TESTS_DIR.is_dir():
        return []

    seen: set[str] = set()
    for pat in ("*.cpp", "*.cc", "*.cxx"):
        for f in TESTS_DIR.glob(pat):
            seen.add(f.stem)

    return sorted(seen)


def existing_presets() -> list[str]:
    data = json_read(ROOT / "CMakePresets.json")
    return [
        p.get("name", "???")
        for p in data.get("configurePresets", [])
        if not p.get("hidden", False)
    ]


# --- Presets Management -------------------------------------------------------


def presets_get_default() -> str:
    config = json_read(CONFIG_FILE)
    return config.get("default_preset", "debug")


def presets_set_default(name: str) -> None:
    config = json_read(CONFIG_FILE)
    config["default_preset"] = name
    json_write(CONFIG_FILE, config)
    log.ok(f"Default preset set to '{name}'")


def presets_resolve(args: argparse.Namespace) -> str:
    if args.preset:
        return args.preset
    if args.release:
        return "release"
    if args.debug:
        return "debug"
    return presets_get_default()


# --- Argparse Helpers --------------------------------------------------------


def argparse_presets(parser: argparse.ArgumentParser) -> None:
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-p", "--preset", help="Build preset")
    group.add_argument(
        "--release", action="store_true", help="Shortcut for --preset release"
    )
    group.add_argument(
        "--debug", action="store_true", help="Shortcut for --preset debug"
    )


def argparse_targets(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "targets",
        nargs="*",
        default=None,
        help="Target(s) to build (default: all)",
    )


# --- Build System ------------------------------------------------------------


def configure(preset: str, verbose: bool = False) -> None:
    log.info(f"Configuring (preset: {preset})")
    cmd = ["cmake", "--preset", preset, "-G", "Ninja"]
    if verbose:
        log.info(f"$ {shlex.join(cmd)}")
    run_or_exit(cmd, "Configure failed")
    src = BUILD_DIR / "compile_commands.json"
    dst = ROOT / "compile_commands.json"
    if src.exists():
        shutil.copy2(src, dst)
    log.ok("Configured")


def build(targets: list[str] | None, preset: str, verbose: bool = False) -> None:
    if not BUILD_DIR.exists():
        configure(preset, verbose=verbose)
    jobs = _cpu_count()
    cmd = ["cmake", "--build", str(BUILD_DIR), "-j", str(jobs)]
    if targets:
        cmd.extend(["--target", *targets])
    label = "all" if not targets else ", ".join(targets)
    log.info(f"Building {label} ({preset})")
    if verbose:
        log.info(f"$ {shlex.join(cmd)}")
    run_or_exit(cmd, "Build failed")
    log.ok("Build complete")


# --- Binary Discovery --------------------------------------------------------


def binaries_find(target: str) -> list[BinaryInfo]:
    base = NEST_DIR / "bin" / target
    if not base.is_dir():
        return []
    results: list[BinaryInfo] = []
    for vdir in sorted(base.iterdir()):
        if not vdir.is_dir() or not vdir.name.startswith("v"):
            continue
        for bdir in sorted(vdir.iterdir()):
            if not bdir.is_dir():
                continue
            binary = bdir / target
            if binary.exists() and binary.is_file() and os.access(binary, os.X_OK):
                results.append(BinaryInfo(vdir.name, bdir.name, binary))
    return results


def interactive_select(options: list[str], prompt: str = "Choose > ") -> str | None:
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
        print(f"  {t.cyan(i)}. {opt}")
    while True:
        try:
            choice = input(f"  {prompt} (1-{len(options)}): ").strip()
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                return options[idx]
        except (ValueError, EOFError):
            pass
        print(f"  Invalid. Enter 1-{len(options)}.")


# --- Interactive runner ------------------------------------------------------


def binary_pick(target: str) -> pathlib.Path:
    binaries = binaries_find(target)
    if not binaries:
        log.exit(f"No built binary found for '{target}'")
    if len(binaries) == 1:
        return binaries[0].path
    versions = sorted({b.version for b in binaries}, reverse=True)
    chosen = interactive_select(versions, "Choose version > ")
    if not chosen:
        log.exit("Selection cancelled")
    subset = [b for b in binaries if b.version == chosen]
    if len(subset) == 1:
        return subset[0].path
    build_types = sorted({b.build_type for b in subset})
    chosen_build = interactive_select(build_types, "Choose configuration > ")
    if not chosen_build:
        log.exit("Selection cancelled")
    return next(b.path for b in subset if b.build_type == chosen_build)


# --- Scaffolding -------------------------------------------------------------


def _tmpl(name: str) -> pathlib.Path:
    return TEMPLATES_DIR / name


def _render(src: pathlib.Path, **kwargs: str) -> str:
    return string.Template(src.read_text()).safe_substitute(kwargs)


def scaffold(name: str, type_: str) -> None:
    target_dir = PROJECTS_DIR / name

    if target_dir.exists():
        log.exit(f"Directory '{name}' already exists")

    target_dir.mkdir(parents=True)

    if type_ == "exe":
        for tmpl in (
            _tmpl("project_exe") / "CMakeLists.txt",
            _tmpl("project_exe") / "main.cpp",
        ):
            out_name = tmpl.name
            (target_dir / out_name).write_text(_render(tmpl, NAME=name))
        log.ok(f"Created executable '{name}'")

    else:
        lib_type = type_.upper()
        (target_dir / "CMakeLists.txt").write_text(
            _render(_tmpl("project_lib") / "CMakeLists.txt", LIB_TYPE=lib_type)
        )
        header_tmpl = (
            "header_shared.hpp" if lib_type == "SHARED" else "header_static.hpp"
        )
        (target_dir / f"{name}.hpp").write_text(
            _render(_tmpl("project_lib") / header_tmpl, NAME=name)
        )
        (target_dir / f"{name}.cpp").write_text(
            _render(_tmpl("project_lib") / "source.cpp", NAME=name)
        )
        log.ok(f"Created {lib_type} library '{name}'")


# --- Command Handlers --------------------------------------------------------


def cmd_list(_: argparse.Namespace) -> None:
    projects = existing_projects()
    tests = existing_tests()
    presets = existing_presets()
    default = presets_get_default()
    print(f"\n  {t.bold('Projects')}")
    if projects:
        for p in projects:
            print(f"    {t.cyan(p)}")
    else:
        print("    (none)")
    print(f"\n  {t.bold('Tests')}")
    if tests:
        for test in tests:
            print(f"    {t.cyan(test)}")
    else:
        print("    (none)")
    print(f"\n  {t.bold('Presets')}")
    if presets:
        for p in presets:
            mark = " *" if p == default else ""
            print(f"    {t.cyan(p)}{mark}")
    else:
        print("    (none)")
    print()


def cmd_build(args: argparse.Namespace) -> None:
    build(args.targets, presets_resolve(args), verbose=args.verbose)


def cmd_run(args: argparse.Namespace) -> None:
    if args.target is None:
        projects = existing_projects()
        if not projects:
            log.exit("No projects found to run")
        chosen = interactive_select(projects, "Choose target > ")
        if not chosen:
            log.exit("Selection cancelled")
        args.target = chosen
    preset = presets_resolve(args)
    build([args.target], preset, verbose=args.verbose)
    binary = binary_pick(args.target)
    log.info(
        f"Running {t.bold(binary.name)} {' '.join(args.args) if args.args else ''}"
    )
    result = subprocess.run([str(binary), *args.args])
    sys.exit(result.returncode)


def cmd_test(args: argparse.Namespace) -> None:
    preset = presets_resolve(args)
    test_names = args.tests
    if test_names:
        build(test_names, preset, verbose=args.verbose)
    else:
        tests = existing_tests()
        if tests:
            build(tests, preset, verbose=args.verbose)
    jobs = _cpu_count()
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
    log.info("Running tests")
    if args.verbose:
        log.info(f"$ {shlex.join(cmd)}")
    run_or_exit(cmd, "Some tests failed")
    log.ok("All tests passed")


def cmd_new(args: argparse.Namespace) -> None:
    scaffold(args.name, args.type)


def cmd_clean(args: argparse.Namespace) -> None:
    if args.all:
        if NEST_DIR.exists():
            shutil.rmtree(NEST_DIR)
            log.ok("Removed .nest/")
        compile_db = ROOT / "compile_commands.json"
        if compile_db.exists():
            compile_db.unlink()
            log.ok("Removed compile_commands.json")
    else:
        for subdir in [BUILD_DIR, NEST_DIR / "lib", NEST_DIR / "bin"]:
            if subdir.exists():
                shutil.rmtree(subdir)
                log.ok(f"Cleaned {subdir.relative_to(ROOT)}/")
    log.ok("Clean complete")


def cmd_preset_list(_: argparse.Namespace) -> None:
    presets = existing_presets()
    default = presets_get_default()
    print()
    for p in presets:
        mark = " *" if p == default else ""
        print(f"  {t.cyan(p)}{mark}")
    print()


def cmd_preset_set(args: argparse.Namespace) -> None:
    presets = existing_presets()
    if args.name not in presets:
        log.exit(f"Unknown preset '{args.name}'. Available: {', '.join(presets)}")
    presets_set_default(args.name)


# --- Init Helpers ------------------------------------------------------------


def init_try_copy(src: pathlib.Path, dst: pathlib.Path) -> None:
    if dst.exists():
        log.warn(f"Skipped {dst.name} - already exists")
    else:
        shutil.copy2(src, dst)
        log.ok(f"Created {dst.name}")


def init_try_write(dst: pathlib.Path, content: str) -> None:
    if dst.exists():
        log.warn(f"Skipped {dst.name} - already exists")
    else:
        dst.write_text(content)
        log.ok(f"Created {dst.name}")


def gitignore_init(dst: pathlib.Path) -> None:
    block = _tmpl("gitignore").read_text()
    if dst.exists():
        current = dst.read_text()
        existing = set(current.splitlines())
        needed = [line for line in block.splitlines() if line not in existing]
        if not needed:
            log.ok(".gitignore already fully covered")
            return
        dst.write_text(current.rstrip() + "\n\n" + "\n".join(needed) + "\n")
        log.ok(f"Extended .gitignore ({len(needed)} new entries)")
    else:
        dst.write_text(block)
        log.ok("Created .gitignore")


def cmd_init(args: argparse.Namespace) -> None:
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

    for tmpl in sorted(TEMPLATES_DIR.iterdir()):
        if not tmpl.is_file():
            continue
        if tmpl.name in ("root_cmakelists.txt", "gitignore", "config.json"):
            continue
        if tmpl.name in ("nest.cmake", "nestConfig.cmake.in"):
            init_try_copy(tmpl, target / "cmake" / tmpl.name)
        else:
            init_try_copy(tmpl, target / tmpl.name)

    init_try_write(
        target / "CMakeLists.txt", _render(_tmpl("root_cmakelists.txt"), NAME=name)
    )

    gitignore_init(target / ".gitignore")

    config_dir = target / ".nest"
    config_dir.mkdir(exist_ok=True)
    init_try_write(config_dir / "config.json", _tmpl("config.json").read_text())

    log.ok(f"Nest project '{name}' initialized")


# --- Main --------------------------------------------------------------------


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
    parser.add_argument("--version", action="version", version=f"nest {version_get()}")

    sub = parser.add_subparsers(dest="command", title="commands")

    p_list = sub.add_parser("list", help="List projects, tests, and presets")
    p_list.set_defaults(func=cmd_list)

    p_init = sub.add_parser(
        "init", help="Initialize a Nest project in the current directory"
    )
    p_init.add_argument("-n", "--name", help="Project name (default: directory name)")
    p_init.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="Prompt to confirm or change project name",
    )
    p_init.set_defaults(func=cmd_init)

    p_build = sub.add_parser("build", help="Build targets")
    argparse_targets(p_build)
    argparse_presets(p_build)
    p_build.add_argument(
        "-v", "--verbose", action="store_true", help="Print raw cmake commands"
    )
    p_build.set_defaults(func=cmd_build)

    p_run = sub.add_parser("run", help="Build and run a target")
    p_run.add_argument(
        "target",
        nargs="?",
        default=None,
        help="Target to run (omit to pick interactively)",
    )
    p_run.add_argument("args", nargs="*", help="Arguments to pass to target")
    argparse_presets(p_run)
    p_run.add_argument(
        "-v", "--verbose", action="store_true", help="Print raw cmake commands"
    )
    p_run.set_defaults(func=cmd_run)

    p_test = sub.add_parser("test", help="Build and run tests")
    p_test.add_argument(
        "tests", nargs="*", default=None, help="Specific tests (default: all)"
    )
    argparse_presets(p_test)
    p_test.add_argument(
        "-v", "--verbose", action="store_true", help="Print raw commands"
    )
    p_test.set_defaults(func=cmd_test)

    p_new = sub.add_parser("new", help="Scaffold a new project")
    p_new.add_argument("name", help="Project name")
    p_new.add_argument(
        "-t",
        "--type",
        choices=["exe", "shared", "static"],
        default="exe",
        help="Project type",
    )
    p_new.set_defaults(func=cmd_new)

    p_clean = sub.add_parser("clean", help="Clean build artifacts")
    p_clean.add_argument("--all", action="store_true", help="Remove .nest/ entirely")
    p_clean.set_defaults(func=cmd_clean)

    p_preset = sub.add_parser("preset", help="Manage build presets")
    p_preset_sub = p_preset.add_subparsers(dest="action", required=True)
    p_preset_list = p_preset_sub.add_parser("list", help="List available presets")
    p_preset_list.set_defaults(func=cmd_preset_list)
    p_preset_set = p_preset_sub.add_parser("set", help="Set default preset")
    p_preset_set.add_argument("name", help="Preset name")
    p_preset_set.set_defaults(func=cmd_preset_set)

    args = parser.parse_args()

    if args.command == "init":
        global ROOT, NEST_DIR, BUILD_DIR, PROJECTS_DIR, TESTS_DIR, CONFIG_FILE
        ROOT = pathlib.Path.cwd().resolve()
        NEST_DIR = ROOT / ".nest"
        BUILD_DIR = NEST_DIR / "build"
        PROJECTS_DIR = ROOT / "projects"
        TESTS_DIR = ROOT / "tests"
        CONFIG_FILE = NEST_DIR / "config.json"
        cmd_init(args)
        return

    if _found_root is None:
        log.exit(
            "not inside a Nest project (no CMakeLists.txt with cmake/nest.cmake found)"
        )

    if args.command is None:
        cmd_list(args)
    else:
        args.func(args)


if __name__ == "__main__":
    main()
