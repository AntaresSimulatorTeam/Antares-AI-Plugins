---
name: antares-context
description: Use when the user asks what an Antares product or tool is (Antares Simulator, Antares Web/AntaREST, Antares Xpansion, GEMS, GemsPy, antares_craft, …), how they relate, which tool fits a task, or which AntaresSimulatorTeam repository holds a given piece.
---

# Antares ecosystem context

This skill only orients the user. It does not operate any tool. Load the reference that matches the question:

- `references/ecosystem.md`: what each product does and how they fit together. Use it for "what is X" or
  "which tool should I use to …" questions.
- `references/repos.md`: public repositories of the AntaresSimulatorTeam GitHub organisation and what each
  holds. Use it for "where is the code / docs for X" questions.

Both files describe public information as of 2026-11. If a question needs current details (versions, options,
install steps), point the user to the product's documentation or repository instead of guessing. For a study on
disk, the `antares-simulator` plugin's `study-check` and `study-metadata` skills do the hands-on work.
