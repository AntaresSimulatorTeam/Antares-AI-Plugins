# GEMS language work: design decisions, parity, interpreter releases (snapshot 2026-11-25)

Read this for: language syntax/semantics choices, library or system file format changes, GemsPy <-> Simulator parity, interpreter release notes.

## Mental model

- GEMS is the **contract**; GemsPy (Python) and Antares_Simulator (C++, hybrid mode first, modeler second) are **two interpreters** of it. Divergence between them is the main language-level product risk: every proposal says what it means for both.
- **Hybrid mode is where Antares effort goes.** Judge Antares feasibility in hybrid terms first: connections to legacy areas, Monte Carlo scenarios optimised one by one, LP vs MILP, Antares horizon and resolution. Known limits (re-verify in `GEMS/doc/interoperability/hybrid/limitations.md`): series must match horizon/resolution; integer/binary variables need MILP; no scenario-independent variables. A construct that is elegant in the language but impossible in hybrid is a priority red flag: scope it to GemsPy/modeler first, or list what hybrid needs.
- **The language is versioned**: language and docs share a version (`GEMS/doc/home/release-notes.md`; current numbers in `versions.md`); `GEMS/COMPATIBILITY.md` maps it to Antares-Simulator and GemsPy versions and defines the rules (patch = backward compatible, minor = new features that older interpreters may not support, major = may break). Libraries have their own versions + CHANGELOG + sha256 in `GEMS/libraries/`. Every language change states its bump level and the COMPATIBILITY.md row it creates.
- Beyond the interpreters, a language change can hit: Xpansion `gems` workflow (optim-config, `antares-problem-generator`), ViewsBuilder (simulation table, taxonomy, catalog, view-config), converters (legacy->GEMS, PyPSA->GEMS output must stay valid), reference libraries, e2e tests (`GEMS/tests/e2e_tests/`: legacy-models equivalence, doc QSE examples, tutorials, PyPSA-Eur). Use `interactions.md` heuristics.

## Where to verify (local clone first, else GitHub; paths are relative to `$ANDROMEDE_ROOT`)

| Question | Look at |
|---|---|
| Current syntax / semantics | `GEMS/doc/user-guide/syntax.md`, `GEMS/doc/user-guide/input-files/<file>.md` |
| Expression grammar, GemsPy | `GemsPy/grammar/Expr.g4` |
| Expression grammar, Simulator | `Antares_Simulator/src/expressions/antlr-interface/Expr.g4` (also ADR `2025-04-22-remove-regex-and-use-antlr.md`) |
| Simulator modeler semantics | `Antares_Simulator/docs/reference/modeler/{05-model,09-expressions,02-inputs}.md` |
| Calendar file | `GEMS/doc/user-guide/input-files/calendar.md` |
| Interpreters side by side | `GEMS/doc/overview/gems-interpreters/{antares-simulator,gemspy}.md` |
| Hybrid behaviour | `GEMS/doc/interoperability/hybrid/*`, `Antares_Simulator/docs/reference/solver/hybrid-studies.md` |
| Is it breaking / which versions | `GEMS/COMPATIBILITY.md`, `GEMS/dependencies.json`, `GEMS/doc/home/release-notes.md` |
| What's shipped / planned | `GEMS/doc/home/features.md`, `GEMS/doc/home/roadmap.md`, GemsPy `docs/CHANGELOG.md`, Simulator `docs/developer-guide/CHANGELOG.md` (unreleased versions: on the `release/<x.y>.x` branch) |
| Web storage of GEMS objects | `AntaREST/antarest/study/business/model/gems/` (what Web accepts and round-trips) |
| Model examples | `GEMS/libraries/*.yml` |

Quick parity probe (run from `$ANDROMEDE_ROOT`): `git -C GemsPy show origin/main:grammar/Expr.g4 | diff - <(git -C Antares_Simulator show origin/develop:src/expressions/antlr-interface/Expr.g4)`. The diff is noisy (rule names, ordering) and covers grammar only: necessary but not sufficient. Never state parity from memory; run the probe and check the classes below against current code, changelogs and tests.

Divergence classes to check:

1. **Precedence and associativity**: the same operators can parse differently (e.g. unary minus vs power: `-2^2`). The diff does not show the effect; confirm with a test in both interpreters before reporting a bug.
2. **Alternative order**: the same alternatives listed in a different order can make ambiguous inputs parse differently.
3. **Semantics outside the grammar**: default time/scenario dependence, aggregation scaling (e.g. `sum(x)` over a block of a time-constant `x`, scaled by the horizon in Simulator 10.3: GemsPy parity to verify), what is allowed where (variables in bounds, nonlinear terms in constraints or objectives), functions available. Check interpreter docs, changelogs and tests.
4. **Interpreter ahead of the spec**: a construct in both grammars but missing from GEMS `syntax.md` / release notes. Flag as spec debt.
5. **One-sided features**: in GemsPy only, in the Simulator only, or stored by AntaREST with no Simulator interpreter behind it. Check GEMS release notes and both changelogs.
6. **Hybrid-only keys**: accepted by GemsPy's hybrid writer (`write_yaml_hybrid_library`) and hybrid studies, rejected by the "full GEMS" format. Check that a proposal says which format it targets.

**Main failure mode: inventing plausible but wrong syntax.** Check syntax in the files above before writing examples; otherwise mark them `(illustrative, check against current spec)`.

## Workflow A: language design decision

1. Restate the **problem from the modeller's point of view** (concrete use case) before any syntax.
2. At least two real options + "do nothing"; compare; recommend; say what would change your mind.
3. Criteria: expressiveness for energy systems | readability close to math notation | unambiguity and self-containedness | implementation cost in both interpreters | backward compatibility and migration | impact on converters and libraries | testability with e2e validation tests | consistency with existing constructs (no special cases) | ecosystem consumers (Xpansion, ViewsBuilder, tooling).
4. Hybrid-mode check (legacy areas, Monte Carlo, LP/MILP, horizon/resolution).
5. One or two worked examples in GEMS YAML / expression notation, verified or marked illustrative.
6. Version impact (patch/minor/major), COMPATIBILITY.md row, docs and examples to update.

### Decision record template

Save Simulator-side decisions in `Antares_Simulator/docs/architecture-decision-record/YYYY-MM-DD-<title>.md`; language decisions belong in the GEMS repo (propose a location if none exists).

```markdown
# DR: <decision title>
Status: proposed | accepted | rejected | superseded by <DR>
Date: <YYYY-MM-DD>   Deciders: <teams>   Affects: spec, libraries, GemsPy, Antares hybrid (modeler?), Xpansion, ViewsBuilder, converters

## Problem (modeller's point of view)
<2-5 sentences, concrete use case>

## Options
### A. <name>
Description, example (verified | illustrative, check against current spec), pros, cons.
### B. <name>
...
### C. Do nothing
Consequences.

## Comparison
| Criterion | A | B | C |
|---|---|---|---|
| Expressiveness | | | |
| Readability | | | |
| Unambiguity | | | |
| Cost GemsPy / Simulator | | | |
| Backward compatibility | | | |
| Converters / libraries | | | |
| Testability (e2e) | | | |
| Consistency | | | |
| Ecosystem consumers | | | |

## Recommendation
<option> because <reasons>. Would change my mind if <conditions>.

## Compatibility, hybrid check, migration
Version bump: patch | minor | major (new COMPATIBILITY.md row: language x.y.z <-> Antares a.b.c <-> GemsPy d.e.f).
Hybrid: legacy areas | Monte Carlo | LP/MILP | horizon/resolution.
Migration of existing models/libraries. Converter impact.

## Work implied
- Spec/docs + release notes: ...
- Libraries (version + CHANGELOG + sha256): ...
- GemsPy (grammar, parser, tests): ...
- Antares_Simulator (grammar, hybrid, modeler): ...
- e2e validation tests: ...
- Other consumers (Xpansion, ViewsBuilder, converters, tooling): ...

## Open questions
- <question> - owner
```

## Workflow B: parity matrix and integration roadmap

- Rows = language features; columns below; cells Done | Partial | Planned | Not planned | Unknown, with a note for every Partial. Mark Unknown honestly; never fill from memory. Add a Modeler column only on request.
- For each gap: user impact, size/risk guess, recommended order, owner. Prioritise by modeller value, unblocking effect, and risk reduction (features stressing the C++ architecture or hybrid constraints first).
- Frame the roadmap as outcomes ("in a hybrid study, a modeller can...") per milestone, not tasks.

```markdown
| Feature | Spec (version) | GemsPy | Antares hybrid | e2e tests | Docs | Xpansion gems | ViewsBuilder | Notes / next step |
|---|---|---|---|---|---|---|---|---|
| <feature> | Done (0.4.0) | Done | Partial | Planned | Done | n/a | n/a | ... |
```

## Workflow C: interpreter release notes

Audience: Antares C++ and GemsPy developers first, then modellers. Title with the language version and the interpreter versions (e.g. "GEMS 0.5.0 / Antares 10.3 / GemsPy 0.3"). Link issues/PRs only when provided; never invent them.

```markdown
# Release notes: GEMS <x.y.z> / Antares <version> / GemsPy <version>

## Action required
- Breaking changes and what to change (models, libraries, tests, pins)
## New language features
## Interpreter changes
- GemsPy: ...   - Antares (hybrid / modeler): ...
## Libraries
- <library> <version>: ...
## Fixes
## Docs and examples
## Compatibility
New COMPATIBILITY.md row and pins to bump (dependencies.json, pyproject pins, antares-version.json).

## Stakeholder summary (max 5 lines)
```
