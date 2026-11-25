# Ecosystem map (snapshot 2026-11-25)

Built from each repo's remote default branch on 2026-11-25. Version numbers live in `versions.md`, doc paths in
`sources.md`.
Local clones (optional): `$ANDROMEDE_ROOT/<repo>`. GitHub organisation: https://github.com/AntaresSimulatorTeam.
"Andromede" is RTE's programme behind GEMS; the `andromede_models` GEMS library is "the library of models from
RTE's Andromede project".

## Layer view

```
 Upstream    antares-datamanager (front + back + generator): reference data in a DB ──► generated Antares study
                   │ builds studies through antares_craft (Web API or local)
           ┌───────▼──────────────── Users ────────────────────────┐
           │ modellers / analysts   Web users   Python scripters   │
           └───────┬───────────────────┬───────────────┬───────────┘
 Interfaces   AntaREST (Antares Web) ◄── antares_craft (local or via Web API)
                   │ launches (local / SLURM via antares-launcher)
 Engines    Antares_Simulator (legacy solver + hybrid + modeler)   GemsPy
                   │ problems / outputs                             │
 Planning    antares-xpansion (Benders, trajectory, gems workflow)  │
 Language    GEMS spec + model libraries  ◄──── interpreted by Simulator and GemsPy
 Outputs     simulation table ──► GEMS-ViewsBuilder (business views) ──► Antares Web output views
 Docs        antares-doc (user doc), GEMS docs, each repo's technical docs
 Adjacent    AntaresLegacyModels-to-GEMS-Converter, PyPSA-to-GEMS-Converter (adoption levers)
```

## Owning teams

For open-question owners and ticket split. Jira components come from the Antares Jira; "-" means none known.

| Team | Jira components | Repos |
|---|---|---|
| Simu (includes GEMS and the converters) | `Simulateur`, `Xpansion` | Antares_Simulator, antares-xpansion, GEMS, converters, GEMS-ViewsBuilder |
| Plateforme | `AntaresWeb`, `antares-craft` | AntaREST, antares_craft, antares-launcher |
| R&D | - | GemsPy |
| PO | - | antares-doc |
| Pegase | `Pegase` | antares-datamanager-front, antares-datamanager-back (generator: to verify) |

A repo with no Jira component of its own: name the team above, and ask for the component rather than inventing one.

## Per repo

### antares-datamanager-{front,back,generator}: study generation (start of the pipeline)
- Role: industrialised, traceable generation of Antares studies from reference data (RTE "PEGASE" tooling; the back
  README: load area, link, load, thermal... data "into a database in order to keep traceability and make the data
  re-usable", then "expose its data for the generation of studies"). The quality of generated studies bounds every
  downstream result.
- Flow: `front` (React/Vite/TS UI, screens per data family) -> `back` (Java / Spring Boot, Postgres + Liquibase,
  OAuth2 + LDAP; exports a **study JSON** and time-series files to the NAS, then calls the generator) ->
  `generator` (Python, FastAPI, `POST /generate_study/`; reads the JSON and feather series, builds the study with
  antares_craft, TS generation with `antares-timeseries-generation`).
- Output: a **legacy-format study (C1)**, created on an Antares Web server (`GENERATION_MODE=API`, default) or
  locally (`LOCAL`); study version from `STUDY_VERSION`. **No GEMS / hybrid output** (grep, 2026-11-25).
- PO angle: any change to C1, craft's object model or Web's study-creation API can break generation. The
  legacy -> GEMS direction implies a GEMS or hybrid output path here, or reliance on the legacy -> GEMS converter:
  an open product question for the Pegase team.

### GEMS: language, docs, libraries
- Role: Generic Energy systems Modelling Schema. Object/graph-oriented modelling language close to maths, plus a
  data structure for energy systems; "getting models out of the code". Hosts the spec, reference libraries
  (`basic_models_library`, `andromede_models`, `antares_legacy_models`, `pypsa_models`, each with CHANGELOG +
  sha256) and e2e validation tests.
- Versioning: language and docs share one version; `COMPATIBILITY.md` maps it to Simulator and GemsPy versions;
  `dependencies.json` pins the Simulator used by e2e tests. Method and templates: `gems-language.md`.

### GemsPy: Python GEMS interpreter
- Role: standalone Python interpreter (PyPI `gemspy`), solver-agnostic; packages `gems_craft` (build/read studies)
  and `gems_runner` (run). Writes simulation tables to disk per scenario (Parquet by default), has a read API and a
  hybrid library writer (`write_yaml_hybrid_library`). Historically the prototype for new language features.
- Users: Python modellers, researchers, converter and ViewsBuilder developers.

### GEMS-ViewsBuilder: business views on outputs (prototype)
- Role: builds views (aggregated perspectives) on a GEMS simulation table. Inputs: system (or
  `system-for-views.yml`), libraries, taxonomy, simulation table (Parquet/CSV), calendar, catalogs of metrics, view
  configs. Output: one file per view and aggregation pattern, read back by Antares Web (C13).
- Roadmap: GEMS "Now" item = integrate directly with Simulator and GemsPy outputs.

### Antares_Simulator: production engine (C++)
- Role: open-source power-system simulator (RTE, MPL-2.0): Monte Carlo, hourly year-long scenarios, adequacy and
  economic studies. Three faces:
  - **Legacy solver** (`antares-solver`): areas, links, thermal/renewable clusters, short-term storage, hydro,
    binding constraints, reserves, thermal ramping.
  - **Hybrid mode**: legacy study + GEMS files in `input/` (`system.yml`, `model-libraries/`, `data-series/`), run
    by `antares-solver`; `system.yml` makes a study hybrid; settings from Antares. Outputs = legacy outputs + one
    simulation table per year and weekly-resolution stage.
  - **Hybrid check** (the one list other files refer to; re-check `GEMS/doc/interoperability/hybrid/limitations.md`):
    connections to legacy areas; Monte Carlo scenarios optimised one by one (so no cross-scenario operators and no
    scenario-independent variables); LP vs MILP (integer variables need MILP); series must match the Antares horizon
    and resolution; legacy outputs and simulation table stay consistent.
  - **Modeler** (`antares-modeler`): GEMS-only, free from the legacy time/uncertainty structure; requires
    `optim-config.yml`.
  - Also: ts-generator, MPS export, adequacy patch, peak shaving.

### antares-xpansion: investment planning
- Role: optimises investment in generation and transmission on top of Antares studies (investment annuity +
  expected operating cost) by Benders decomposition. Executables: `antares-solver`, `lp_namer`, `benders`,
  `xpansion-study-updater`, `antares-problem-generator` (GEMS workflow). Orchestrator
  `launch.py --step {full, antares, problem_generation, benders, gems, study_update, sensitivity, presolve, resume}`.
- GEMS link: the `gems` step, auto-activated when `input/optim-config.yml` exists.
- Direction: **trajectory (pluriannual) investment** on a scenario tree of annual studies
  (`docs/reference/trajectory-investment/`), robust resume, micro-iterations.

### antares_craft: Python API for Antares studies
- Role: Python library (PyPI `antares_craft`) to read and edit studies **locally or on an Antares Web server** (one
  object model, mirrors Web naming), variants on Web, launch simulations, read outputs, generate availability time
  series, configure Xpansion.
- GEMS / hybrid support: **none** in releases or on `main` (grep, 2026-11-25). antares-doc lists "GEMS usable with
  Antares Craft and Antares Web" as in progress, so this is a known gap.

### AntaREST: Antares Web
- Role: web API + React UI over Antares studies: study ids and HTTP API, matrix storage, **variant manager**
  (command-based edits), users and permissions, study upgrade, results views, Xpansion view, launcher (`local` or
  `slurm`, SLURM through `antares-launcher`).
- GEMS: libraries, models, components, area and thermal connections, data series, calendar, taxonomy, catalogs,
  scenario builder and `integer-strategy` are stored in its database and exposed through the API
  (`antarest/study/business/model/gems/`, `antarest/study/dao/database/gems/`); hybrid studies can be launched;
  GEMS outputs are flagged and **views produced by ViewsBuilder are read from `<output>/views/`**
  (`antarest/output/filestudy/gems_views.py`). Which of this the UI exposes, and who runs ViewsBuilder in a Web
  run: to verify (not described in `docs/`).

### antares-launcher: SLURM batch submission
- Role: CLI sending Antares studies to a remote SLURM cluster (ssh, STUDIES-IN / FINISHED / LOGS directories); used
  as a library by AntaREST's SLURM launcher. GEMS-agnostic (runs a study folder). The README's "studies 7.0
  through 8.5" is outdated.

### antares-doc: user documentation
- Role: MkDocs-Material **user documentation of the whole suite** (Web, Craft, Simulator, Modeler CLI, Xpansion),
  default branch `master`, published at https://antares-doc.readthedocs.io/. Technical docs stay in each repo.
- Layout (`docs/`, nav in `mkdocs.yml`): `overview/` (use cases, deployment, architecture, **changelogs**,
  **roadmap**), `getting-started/`, `tutorials/`, `programmatic/` (Craft, `antares-solver-cli`, `modeler-cli`,
  `antares-xpansion-cli`), `reference/`, `contributing/`.
- Release notes (`overview/changelogs.md`) are a curated user feed linking to each repo's technical changelog.
- Gaps (grep, 2026-11-25): no page on GEMS / hybrid beyond the roadmap line and the modeler CLI page.
- Conventions (`AGENTS.md`): one H1 per page, sentence-case headings, every new page in `nav`, 100-char soft line
  limit, `uv sync` + `mkdocs serve`.
- Any user-visible Simulator / Web / Xpansion / Craft change implies an antares-doc update (release note, tutorial
  or reference page, roadmap line).

## Adjacent repos
- `AntaresLegacyModels-to-GEMS-Converter`: legacy study -> GEMS study (area, load, link, renewable, thermal,
  short-term storage) using `antares_legacy_models`. Also hosts the legacy taxonomy, catalogs and view configs
  (`src/antares_gems_converter/{taxonomies,catalogs,views_config}`), the reference for legacy outputs through
  ViewsBuilder, and an `antares_legacy_investment_candidates` library (new in 2026-11).
- `PyPSA-to-GEMS-Converter`: PyPSA network -> GEMS study, using `pypsa_models`; results comparable with PyPSA.
