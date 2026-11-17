---
name: study-metadata
description: Use when the user asks for an Antares Simulator study's name (caption), author, format version, creation or last-save date, or wants to rename a study or change its author. Works on the study.antares file of a study on disk.
---

# Read or update Antares study metadata

Study metadata lives in the `[antares]` section of `study.antares` at the study root
(Antares_Simulator `src/libs/antares/study/header.cpp:49-72`):

| Key | Meaning | Notes |
|-----|---------|-------|
| `caption` | Study name | Default `No title` |
| `author` | Author | Default `Unknown` |
| `version` | Study format version | `10.3`, or a legacy integer such as `880` (= 8.8) |
| `created` | Creation date | Unix timestamp (seconds) |
| `lastsave` | Last save date | Unix timestamp. Written as `lastSave`. Keys are read case-insensitively |
| `editor` | Last editor | Written on save, never read back by the solver |

## Read (default)

1. Find the study root: the folder that contains `study.antares`. Walk up if the user gave a subfolder. If there
   are several studies, ask which one.
2. Read the `[antares]` section and report every key present.
   - Convert `created` and `lastsave` to readable dates and keep the raw value in brackets.
   - Mention missing keys and the default the solver uses for them.

## Update (only on request, after confirmation)

- Only `caption` and `author` can be changed by this skill.
- Show the current line, the new line and the file path. Wait for an explicit yes before writing.
- Change only that line. Keep every other line, the key order, the `[antares]` header and the line endings.
- Re-read the file and show the result.
- **Never edit `version`.** Changing the number does not convert the data. Studies are upgraded with the
  `antares-study-version` tool (github.com/AntaresSimulatorTeam/antares-study-version).
- Don't change `created`, `lastsave` or `editor`.

This skill covers studies on disk. For a study managed through Antares Web, say that its metadata in the web
application is outside this skill's scope.
