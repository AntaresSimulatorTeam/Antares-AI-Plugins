# Eval cases: `antares-simulator:study-check`

Run each prompt in a fresh session with the plugin installed, from a folder holding the fixture described.

## 1. Valid study, static check only

- **Setup:** a study at version 10.3 with `study.antares`, a `settings/generaldata.ini` using only known sections
  and `mode = economy`, and `input/areas/list.txt` listing `FR` and `DE` with folders `input/areas/fr/` and
  `input/areas/de/`.
- **Prompt:** "Can you check the study in ./my-study before I run it?"
- **Expected:**
  - The skill triggers.
  - Reads the files only. Doesn't call `antares-solver` and doesn't write anything.
  - Reports the caption and version 10.3, with every check OK.
  - Lists what a run would write (`output/…`, `logs/…`, and that `[input] import` is empty, so nothing goes into
    `input/`).
  - Offers an optional solver run on a copy.

## 2. Broken study, several problems

- **Setup:** `study.antares` with `version = 11.0`, `generaldata.ini` with a `[genral]` section and
  `mode = simulation`, and `list.txt` listing `FR Paris/Nord` with no `input/areas/fr paris nord/` folder.
- **Prompt:** "antares-solver refuses this study, what's wrong with it?"
- **Expected:**
  - Reports all three problems, each with its file and line:
    - version 11.0 is above the supported maximum (10.3 at the reference commit),
    - unknown section `[genral]`, which the solver treats as an error,
    - invalid `mode` value.
  - Reports the missing folder under the converted id `fr paris nord`.
  - Proposes no edit without asking.

## 3. Request to run the solver

- **Prompt:** "Validate ./my-study with the solver itself."
- **Expected:**
  - Explains that `antares-solver` has no check-only mode and that a run writes into the study.
  - Asks for confirmation, then copies the study and runs `antares-solver -i <copy>`, optionally with `-y 1`.
  - Never runs on the original and never passes `--force`.
  - Reports the log from `<copy>/logs/`, kept apart from its own static findings.

## 4. Not a study

- **Setup:** a folder with no `study.antares` anywhere above it.
- **Prompt:** "Check the Antares study in ./data."
- **Expected:** says no `study.antares` was found, so this is not an Antares Simulator study, and stops.
