---
name: study-check
description: Use when the user asks to check, validate or sanity-check an Antares Simulator study folder, asks whether a study is ready to run, or asks why antares-solver refuses to load a study. Inspects the study files without running the solver.
---

# Check an Antares Simulator study

`antares-solver` has **no check-only mode**: every invocation loads the study, writes into it and runs the
simulation (see `references/solver-cli.md`). So this check reads the study files directly. Running the solver is
an optional last step that needs the user's confirmation.

Read `references/study-layout.md` before you start. It lists the files, sections and values used below.

## Procedure

1. **Find the study root.** It is the folder that contains `study.antares`. If the user points at a subfolder
   (`input/`, `settings/`, `output/<run>/`), walk up to the root. If there is no `study.antares`, stop: this is
   not an Antares Simulator study.
2. **Header.** Parse the `[antares]` section of `study.antares`.
   - `version` must be one of the supported versions. Old studies use the integer form (`880` = 8.8).
   - A version newer than the user's solver will not load. Report the study version so the user can compare it
     with `antares-solver --version`.
   - A missing `[antares]` section makes the study invalid.
3. **Settings.** `settings/generaldata.ini` must exist and parse as INI (`[section]`, `key = value`).
   - Check `[general] mode`. Valid values: `economy`, `economic`, `adequacy`, `expansion`, case-insensitive.
   - Report unknown section names: the solver treats them as errors. Don't flag unknown keys: the key list in
     the reference is not exhaustive.
4. **Inputs.** `input/areas/list.txt` must exist. Every area it lists should have a folder
   `input/areas/<area id>/`. The id is not the raw name: convert it as described in the reference.
   For more checks on individual time-series or cluster files, see the layout reference. Report each problem,
   not just the first one.
5. **Write risks of a run.** Tell the user what a solver run would write into this study:
   - an `output/<YYYYMMDD-HHMM><eco|adq|exp>[-name]/` folder,
   - a `logs/solver-<timestamp>.log` file,
   - and, only if `[input] import` lists time-series kinds and the study is at the latest version, new
     `input/<kind>/series/` files.
6. **Optional solver run.** Offer it only if the user wants the solver's own diagnostics. Ask first, then run it
   on a **copy** of the study, never on the original:
   `antares-solver -i <copy-of-study>`. Use `-y 1` to cut the number of Monte-Carlo years if the user agrees.
   Read the log under `<copy>/logs/` and report loading errors and warnings. Do not pass `-f/--force`: it
   suppresses the loading errors you are looking for.

## Report

- Study root, `caption` and `version`.
- Checks performed, each marked OK / problem / not checked.
- Problems, with file path and the exact offending line or key.
- Whether the solver was run, on which copy, and what its log reported. Keep solver-reported findings apart
  from your own reading of the files.

Never edit the study as part of this skill. If the user wants a problem fixed, describe the change and ask before
making it.
