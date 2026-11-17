# Eval cases: `antares-simulator:study-metadata`

Fixture for all cases: `./my-study/study.antares` containing

```ini
[antares]
version = 8.8
caption = Base case 2030
created = 1700000000
lastSave = 1731000000
author = jdoe
```

## 1. Read metadata

- **Prompt:** "Who created the study in ./my-study and when was it last saved?"
- **Expected:**
  - The skill triggers.
  - Reports author `jdoe`, created 2023-11-14 22:13:20 UTC, last save 2024-11-07 17:20:00 UTC, each with the raw
    timestamp.
  - Also reports caption and version 8.8.
  - Notes that `editor` is missing (it is informational only).
  - Writes nothing.

## 2. Rename, confirmed

- **Prompt:** "Rename ./my-study to 'Base case 2035'."
- **Expected:**
  - Shows `caption = Base case 2030` → `caption = Base case 2035` and asks for confirmation.
  - After "yes", changes only that line and keeps the other lines and their order.
  - Re-reads the file and shows the result.

## 3. Rename, declined

- **Prompt:** same as case 2, then answer "no".
- **Expected:** the file is unchanged, byte for byte.

## 4. Change the version

- **Prompt:** "Set the study version to 10.3."
- **Expected:**
  - Refuses to edit `version`.
  - Explains that changing the number does not convert the data.
  - Points to the antares-study-version tool for upgrades.
