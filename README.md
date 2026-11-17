# Antares AI Plugins

Claude Code plugins for the [Antares](https://antares-simulator.org) ecosystem, published as a plugin marketplace
named `antares`.

## Who it's for

Study engineers who build, check and run Antares Simulator studies and want an assistant that knows the study
format and tools. The skills are read-only by default and ask before changing a study.

## Plugins

| Plugin | Skill | Use it to |
|--------|-------|-----------|
| `antares-simulator` | `study-check` | Check a study folder before running it, or find out why the solver rejects it |
| `antares-simulator` | `study-metadata` | Read a study's caption, author, version and dates, or rename it |
| `antares-context` | `antares-context` | Find out what each Antares product does and which repository holds what |

Each skill is self-contained: it carries all the context it needs in its own folder. `antares-context` only holds
general knowledge about the ecosystem, not tied to any skill. You can install either plugin on its own.

Skills trigger on their own when a request matches. You can also call them directly, for example
`/antares-simulator:study-check ./my-study`.

## Install

In Claude Code:

```
/plugin marketplace add AntaresSimulatorTeam/Antares-AI-Plugins
/plugin install antares-simulator@antares
/plugin install antares-context@antares
```

Or from a shell:

```bash
claude plugin marketplace add AntaresSimulatorTeam/Antares-AI-Plugins
claude plugin install antares-simulator@antares
claude plugin install antares-context@antares
```

To try a local checkout, use `claude plugin marketplace add ./Antares-AI-Plugins` instead.

## Use with GitHub Copilot

The Claude marketplace commands above install Claude Code plugins; GitHub Copilot uses the skills in those
plugins as [agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills). From the
repository where you want to use them, install the skills with GitHub CLI 2.90.0 or later:

```bash
gh skill install AntaresSimulatorTeam/Antares-AI-Plugins plugins/antares-simulator/skills/study-check --agent copilot --scope project
gh skill install AntaresSimulatorTeam/Antares-AI-Plugins plugins/antares-simulator/skills/study-metadata --agent copilot --scope project
gh skill install AntaresSimulatorTeam/Antares-AI-Plugins plugins/antares-context/skills/antares-context --agent copilot --scope project
```

Install only the skills you need. Project-scoped skills are added to the current repository and are available to
Copilot agents that support [agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills).
Ask Copilot to perform a matching task, or mention the skill by name in your prompt.

## Layout

```
.claude-plugin/marketplace.json        marketplace "antares"
plugins/
  antares-simulator/
    .claude-plugin/plugin.json
    agents/                             optional specialized subagents
    skills/
      study-check/SKILL.md             + references/ (study layout, solver CLI)
      study-metadata/SKILL.md
  antares-context/
    .claude-plugin/plugin.json
    skills/antares-context/SKILL.md    + references/ (ecosystem, repos)
evals/<skill>/cases.md                 test prompts and expected behaviour
```

Plugins are the installable units in the marketplace. They bundle user-facing skills and can also include
specialized agents. Put a skill at `plugins/<plugin>/skills/<skill-name>/SKILL.md`; skills describe a capability
that Claude can load when a request matches. Put an agent definition at
`plugins/<plugin>/agents/<agent-name>.md` for a specialized subagent, typically for substantial side tasks.

Evals are different: `evals/<skill-name>/cases.md` contains prompts and expected behaviour for checking a skill.
These cases are for evaluation, not plugin components, and are not installed with a plugin.

Skills must sit directly under `skills/<skill-name>/SKILL.md`. Claude Code does not discover skills in deeper
folders.

## MCP servers

No MCP server is referenced yet. Each server will live in the repository of the API it wraps (for example
AntaREST). Once one exists, the plugin that uses it gets a `.mcp.json` at its root, next to `skills/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MPL-2.0](LICENSE), like Antares Simulator. Copyright RTE.
