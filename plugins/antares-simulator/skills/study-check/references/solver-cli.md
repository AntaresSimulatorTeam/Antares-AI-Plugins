# antares-solver command line

Source: Antares_Simulator at commit `6e6a038` (2026-11-16). Options are defined in `src/solver/misc/options.cpp`
and documented in `docs/reference/solver/command-line.md`. Run `antares-solver --help` for the installed version.

## Usage

```
antares-solver -i <study folder> [options]
antares-solver <study folder> [options]
```

The study folder can also be given as a positional argument (`options.cpp:222`).

## Options used by these skills

| Option | Effect |
|--------|--------|
| `-i, --input=PATH` | Study folder |
| `-v, --version` | Print the solver version and exit |
| `-h, --help` | Print help and exit |
| `-l, --list-solvers` | List available OR-Tools solvers and exit |
| `-y, --year=N` | Override the number of Monte-Carlo years |
| `-n, --name=NAME` | Name of the simulation (suffix of the output folder) |
| `--output=VALUE` | Output families to write: `all`, `none`, `monte-carlo` (default), `simulation-tables` |
| `--no-ts-import` | Do not import generated time series into `input/` |
| `-f, --force` | Continue despite loading errors. The code says "Ignore all errors at loading" (`options.cpp:56`) |

The other options (mode overrides, parallelism, linear-solver selection, MPS export, …) are listed in
`command-line.md`.

## There is no check-only mode

- `options.cpp:18-178` defines no check, validate or dry-run option.
- `src/solver/main.cpp:116-117` always calls `application.prepare()` and then `application.execute()`.
- Loading errors stop the run unless `--force` is given: "The simulation must stop."
  (`src/solver/application/application.cpp:260-269`).
- The result writer is created **before** a loading error is raised, so that logs can be copied to the output
  (`application.cpp:233-241`). A run on a broken study can therefore still create an output folder.

## What a run writes into the study

- `logs/solver-YYYYMMDD-HHMMSS.log` (`application.cpp:488-497`).
- `output/<YYYYMMDD-HHMM><eco|adq|exp>[-name]/` (`src/libs/antares/study/study.cpp:185-197`), unless
  `--output=none`.
- After the simulation, `input/<kind>/series/` files for each kind listed in `[input] import` that is also
  generated (`[general] generate`). Thermal is a special case: some clusters can force generation
  (`study.importprepro.cpp:15-80`, `parameters.cpp:1750-1759`, call at `application.cpp:483`).
  - This is disabled when the study is not at the latest version (`load.cpp:83-88`) or with `--no-ts-import`
    (`parameters.cpp:1609-1612`).

To keep a study untouched, run the solver on a copy.
