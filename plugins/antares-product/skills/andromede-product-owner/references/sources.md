# Primary sources per repo (snapshot 2026-11-25)

Where to read first, once the references are not enough. Paths are relative to each repo root (`$ANDROMEDE_ROOT/<repo>`
or GitHub). For GEMS language questions (syntax, grammars, parity), use the "Where to verify" table of
`gems-language.md` instead. Unreleased Simulator and Xpansion notes live on their `release/*` branches.

| Repo | Read first | Published docs |
|---|---|---|
| antares-datamanager-back | `README.md`, `.../controller/`, `src/main/resources/db/changelog/` | none |
| antares-datamanager-generator | `README.md`, `src/antares/datamanager/generator/generate_study_process.py`, `core/settings.py`, `models/study_data_json_model.py` (C11) | none |
| antares-datamanager-front | `src/pages/pegase` | none |
| GEMS | `README.md`, `doc/home/{roadmap,key-principles,features,release-notes}.md`, `doc/overview/architecture.md`, `doc/user-guide/outputs/*`, `doc/interoperability/{legacy,pypsa-to-gems-converter}/` | https://gems-energy.readthedocs.io/en/latest/ |
| GemsPy | `README.md`, `docs/user-guide/{building,converters,inputs,optim-config,optimisation,outputs,scenario-builder}.md`, `docs/CHANGELOG.md` | https://gemspy.readthedocs.io/en/latest/ |
| GEMS-ViewsBuilder | `README.md`, `docs/{index,getting-started,developer-guide}.md`, `docs/user-guide/`; GEMS `doc/user-guide/input-files/{taxonomy,catalog,view-config}.md`, `doc/user-guide/outputs/views.md` | - |
| Antares_Simulator | `docs/reference/solver/hybrid-studies.md`, `docs/reference/modeler/0*-*.md`, `docs/reference/migration-guides.md`, `docs/architecture-decision-record/*`, `docs/architecture/*`, `docs/developer-guide/{simulation-table-e2e-coverage,8-study-format-conventions}.md`, `docs/developer-guide/CHANGELOG.md` (`NEWS.md` only points to it) | https://antares-simulator.readthedocs.io/ (technical) |
| antares-xpansion | `README.md`, `docs/reference/cli.md`, `docs/reference/inputs/*`, `docs/developer-guide/xpansion-steps/index.md`, `docs/reference/trajectory-investment/*`, `docs/overview/CHANGELOG.md`, `conception/Architecture_decision_records/` | https://antares-xpansion.readthedocs.io/ |
| antares_craft | `README.md`, `docs/getting-started/architecture.md`, `docs/api-reference/`, `docs/CHANGELOG.md` | https://antares-craft.readthedocs.io/ |
| AntaREST | `docs/{index,architecture,configuration,database,add-new-antares-version}.md` (`configuration.md`: launcher binaries per version), `docs/CHANGELOG.md` | https://antares-web.readthedocs.io/ |
| antares-launcher | `README.md`, `CHANGES.md`, `doc/` | - |
| antares-doc | `mkdocs.yml` (nav), `docs/overview/{changelogs,roadmap}.md`, `AGENTS.md` | https://antares-doc.readthedocs.io/ (user doc of the whole suite) |
