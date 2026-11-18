# Antares AI Plugins

Claude Code plugins for the [Antares](https://antares-simulator.org) ecosystem, published as a plugin marketplace
named `antares`.

## Who it's for

Study engineers who build, check and run Antares Simulator studies, and Antares contributors who prepare Jira
tickets. Study skills are read-only by default and ask before changing a study; Jira ticket creation requires
an explicit confirmation.

## Plugins

| Plugin | Skill | Use it to |
|--------|-------|-----------|
| `antares-simulator` | `study-check` | Check a study folder before running it, or find out why the solver rejects it |
| `antares-simulator` | `study-metadata` | Read a study's caption, author, version and dates, or rename it |
| `antares-context` | `antares-context` | Find out what each Antares product does and which repository holds what |
| `antares-jira` | `creer-tickets-jira` | Create and verify already-framed Antares Jira tickets after confirmation |

Each skill is self-contained: it carries all the context it needs in its own folder. `antares-context` only holds
general knowledge about the ecosystem, not tied to any skill. You can install either plugin on its own.

## Review pull requests in this repository

The project-scoped `.github/skills/pr-review` skill guides Copilot reviews of changes to these plugins, skills,
and their documentation. The `PR Reviewer` agent in `.github/agents/pr-review.agent.md` provides the same
read-only review flow for manual use. These reviews check the diff and repository conventions; this repository
has no build or test suite. For a manual review, select `PR Reviewer` in Copilot or ask Copilot to use
`pr-review` on the pull request.

To have GitHub Copilot review PRs automatically, a repository administrator can enable **Automatically request
Copilot code review** in the repository's ruleset/branch rules. Individual users can also enable automatic reviews
for their own PRs in Copilot settings. The repository custom instructions and project skill are available to
Copilot Code Review when it runs; make sure the **Use custom instructions when reviewing pull requests** setting
is enabled. These options are configured in GitHub settings, not by a workflow in this repository.

To use the review skill in another repository, install it with GitHub CLI from that repository:

```bash
gh skill install AntaresSimulatorTeam/Antares-AI-Plugins .github/skills/pr-review --agent copilot --scope project
```

Skills trigger on their own when a request matches. You can also call them directly, for example
`/antares-simulator:study-check ./my-study`.

## Install

In Claude Code:

```
/plugin marketplace add AntaresSimulatorTeam/Antares-AI-Plugins
/plugin install antares-simulator@antares
/plugin install antares-context@antares
/plugin install antares-jira@antares
```

Or from a shell:

```bash
claude plugin marketplace add AntaresSimulatorTeam/Antares-AI-Plugins
claude plugin install antares-simulator@antares
claude plugin install antares-context@antares
claude plugin install antares-jira@antares
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
gh skill install AntaresSimulatorTeam/Antares-AI-Plugins plugins/antares-jira/skills/creer-tickets-jira --agent copilot --scope project
```

Install only the skills you need. Project-scoped skills are added to the current repository and are available to
Copilot agents that support [agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills).
Ask Copilot to perform a matching task, or mention the skill by name in your prompt.

The Jira skill requires access to the Antares Jira instance and a personal PAT. Its included setup script stores
the PAT locally; never place a PAT in a chat or in the repository. See the skill's workflow for platform prerequisites.

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
  antares-jira/
    .claude-plugin/plugin.json
    skills/creer-tickets-jira/SKILL.md + references/ and scripts/
.github/
  copilot-instructions.md             repository-wide Copilot guidance
  agents/pr-review.agent.md           read-only PR review agent
  skills/pr-review/SKILL.md           Copilot PR review skill
evals/<skill>/cases.md                 test prompts and expected behaviour
```

Plugins are the installable units in the marketplace. They bundle user-facing skills and can also include
specialized agents. Put a skill at `plugins/<plugin>/skills/<skill-name>/SKILL.md`; skills describe a capability
that Claude can load when a request matches. Put an agent definition at
`plugins/<plugin>/agents/<agent-name>.md` for a specialized subagent, typically for substantial side tasks. No
plugin ships an agent yet, so there is no `agents/` folder in the tree above.

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
