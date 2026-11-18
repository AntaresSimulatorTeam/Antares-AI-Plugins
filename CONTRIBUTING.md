# Contributing a skill

## Where it goes

- Add the skill to an existing plugin if it fits: `plugins/<plugin>/skills/<skill-name>/SKILL.md`.
- Keep one level only. `skills/<group>/<skill>/` is not discovered.
- A Copilot skill intended only for this repository (not distributed as a plugin) can live in
  `.github/skills/<skill-name>/SKILL.md`.
- The folder name and the `name` in the frontmatter must be identical: lowercase letters, digits and hyphens.
- A new plugin needs `plugins/<plugin>/.claude-plugin/plugin.json` and an entry in `.claude-plugin/marketplace.json`.
  The plugin `name` must be the same in both.

## Self-contained skills, general context

- **Each skill is self-contained.** Everything it needs (file layout, CLI options, values, procedure) lives in
  its own folder: in `SKILL.md` or in `skills/<skill-name>/references/`. A skill never points to another skill's
  files, and never relies on `antares-context` being installed. If two skills need the same fact, each one gets
  its own copy, cut to what that skill uses.
- **`antares-context` holds general knowledge only.** It covers things that are true regardless of the task: what
  each product is, how they relate, which repository holds what. It doesn't name or point to specific skills, and
  task-specific details don't go there.

Test: delete every other skill and the `antares-context` plugin. Your skill must still work.

## How to write it

- **Frontmatter:** `name` and `description`. Write the description as a trigger: *when* to use the skill ("Use
  when the user asks …"), not only what it does.
- **Ground every fact.** Every command, flag, path and behaviour must come from the tool's source or official
  docs. Cite the file in `references/`. If you can't verify something, leave it out and say so in your PR.
- **Keep `SKILL.md` short.** Put the procedure in `SKILL.md`, long reference material in `references/*.md`, and
  say in `SKILL.md` when to read each file.
- **Read-only by default.** Any change to a study needs the user's confirmation first.
- **Public information only.** This repository is public.
- Skip boilerplate the model already follows, such as "don't access source repositories".
- Subagents (`agents/`) are only for long side tasks whose output would flood the conversation. Short tasks are
  skills.

## Evals

Add `evals/<skill-name>/cases.md` with 3 or 4 prompts: the nominal case, an error case, a case that needs
confirmation, and an out-of-scope case. Give the expected behaviour for each.

## Check before opening a PR

```bash
claude plugin validate . --strict
claude plugin marketplace add ./
claude plugin install <plugin>@antares
claude plugin details <plugin>@antares
```

`details` must list your skill. Then run your eval prompts in a session.

Bump `version` in the plugin's `plugin.json` when you change it, so installed copies update. Use conventional
commits (`feat(antares-simulator): …`, `fix: …`, `docs: …`).
