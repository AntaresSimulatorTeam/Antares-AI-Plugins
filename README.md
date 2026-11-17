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

## Layout

```
.claude-plugin/marketplace.json        marketplace "antares"
plugins/
  antares-simulator/
    .claude-plugin/plugin.json
    skills/
      study-check/SKILL.md             + references/ (study layout, solver CLI)
      study-metadata/SKILL.md
  antares-context/
    .claude-plugin/plugin.json
    skills/antares-context/SKILL.md    + references/ (ecosystem, repos)
evals/<skill>/cases.md                 test prompts and expected behaviour
```

Skills must sit directly under `skills/<skill-name>/SKILL.md`. Claude Code does not discover skills in deeper
folders.

## MCP servers

No MCP server is referenced yet. Each server will live in the repository of the API it wraps (for example
AntaREST). Once one exists, the plugin that uses it gets a `.mcp.json` at its root, next to `skills/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MPL-2.0](LICENSE), like Antares Simulator. Copyright RTE.
