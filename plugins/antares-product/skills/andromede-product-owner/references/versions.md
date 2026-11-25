# Versions and pins (snapshot 2026-11-25)

This file holds every fact in this skill that ages quickly: release numbers, pins and known lags. Other reference
files avoid version numbers and point here instead, so a refresh only touches this file.

Read on 2026-11-25 from each repo's **remote default branch**, plus release branches where stated. Re-check with
`scripts/ecosystem_status.sh --fetch` (PowerShell: `scripts\ecosystem_status.ps1 -Fetch`) and the file named in the last column; repo files win on conflict.

## Releases and work in progress

| Repo (default branch) | Last release | Default branch / in progress | Check in |
|---|---|---|---|
| GEMS (`main`) | language + docs v0.6.0 (2026-10-28) | v0.6.1 has a `COMPATIBILITY.md` row (Antares 10.2.0, GemsPy 0.3.0) but no release-notes entry yet. Since v0.6.0: `time-dependent` / `scenario-dependent` optional and `true` by default; heuristic `inputs`/`outputs` entries must set `type`; hybrid study e2e test fixed; legacy-to-GEMS tutorial | `doc/home/release-notes.md`, `COMPATIBILITY.md` |
| GEMS libraries | basic_models_library 1.1.0 (2026-11-03: `area-connection` on the `flow` port, for hybrid), antares_legacy_models 2.4.0 (spillage and unsupplied-energy bounds in `area-connection`; needs GemsPy >= 0.3.0), pypsa_models 2.0.1, andromede_models 1.0.0 | The library table of `COMPATIBILITY.md` still says basic 1.0.1 | `libraries/CHANGELOG-*.md`, `version` in each `.yml` |
| GemsPy (`main`) | v0.4.0 (2026-11-20), v0.3.0 (2026-10-29) | `Unreleased` section empty | `docs/CHANGELOG.md` |
| GEMS-ViewsBuilder (`main`) | v0.1.1 (2026-10-30) | `main` already pins `gemspy==0.4.0`; `docs/CHANGELOG.md` is still a stub | `pyproject.toml`, git log |
| Antares_Simulator (`develop`) | 10.2.0 (2026-10-02); 9.3.13 (2026-11-17, maintenance) | **10.3.0-rc4** (2026-11-18, branch `release/10.3.x`); `develop` CMake reads 10.3.0 | 10.3 notes: `docs/developer-guide/CHANGELOG.md` **on `release/10.3.x`** (the `develop` copy has no 10.3 section yet); `docs/reference/migration-guides.md` |
| antares-xpansion (`develop`) | 1.9.0 (2026-06-29) | **1.10.0-rc2** (2026-11-18, branch `release/1.10.x`): robust resume, skeleton subproblem mode, micro-iterations config file, Simulator 10.2.0. `develop` CMake and changelog still read 1.8.0 | `docs/overview/CHANGELOG.md` on the release branch |
| antares_craft (`main`) | 0.17.1 (2026-09-15) | Unreleased on `main`: Simulator 10.2 support except districts and reserves (#443), district model (#444, #447), **breaking**: output reading drops `id` files (#448) | `docs/CHANGELOG.md`, git log |
| AntaREST (`dev`) | v2.37.0 (changelog dated 2026-11-25) | - | `docs/CHANGELOG.md` |
| antares-launcher (`main`) | v1.6.0 (2026-07-28) | one commit since (job ID in the `squeue` format) | `CHANGES.md` |
| antares-doc (`master`) | not released; last change 2026-11-04 | release notes reach Antares Web v2.36 (none for Simulator 10.2, Xpansion 1.9 / 1.10, Web 2.37); the Xpansion changelog link points to `docs/changelog/CHANGELOG.md` (actual: `docs/overview/CHANGELOG.md`); the roadmap page (2026-06-04) still lists reserves and Parquet outputs as in progress | `docs/overview/changelogs.md` |
| antares-datamanager-front / back (`develop`), generator (`main`) | 1.5.0 (`1.5.0-release` tags 2026-11-06 to 2026-11-12; older tags read 1.13.0, 1.14.0) | branches read `1.5.0-rc` | `package.json`, `pom.xml`, `pyproject.toml` |
| AntaresLegacyModels-to-GEMS-Converter (`main`) | v0.5.2 (2026-11-18) | new `antares_legacy_investment_candidates` library 1.0.0; its legacy library copy is at 2.4.0, like GEMS | `src/antares_gems_converter/libs/*/CHANGELOG-*.md` |
| PyPSA-to-GEMS-Converter (`main`) | v0.0.2 (2026-09-18) | - | - |

## Pins to check when sequencing a release

| Pin | File | Value | Gap |
|---|---|---|---|
| Simulator used by GEMS e2e tests | `GEMS/dependencies.json` | 10.2.0 | 10.3 in release candidate |
| Language <-> interpreters | `GEMS/COMPATIBILITY.md` | v0.6.1 <-> Antares 10.2.0, GemsPy 0.3.0 | GemsPy 0.4.0 released |
| GemsPy used by GEMS | `GEMS/pyproject.toml` | `gemspy==0.3.0` | 0.4.0 |
| GemsPy used by ViewsBuilder | `GEMS-ViewsBuilder/pyproject.toml` | `gemspy==0.4.0` | ahead of GEMS |
| GemsPy used by the legacy converter | `AntaresLegacyModels-to-GEMS-Converter/pyproject.toml` | `gemspy==0.3.0` | 0.4.0 |
| Simulator used by Xpansion | `antares-xpansion/antares-version.json` (develop and `release/1.10.x`) | 10.2.0; or-tools-rte 9.13-rte1.3 | 10.3 in release candidate |
| Launcher used by Web | `AntaREST/pyproject.toml` | `antares-launcher==1.6.0` | none |
| Study versions in Web | `AntaREST/antarest/study/model.py` | new studies default to 10.2; 10.3 is declared (ramp parameters require 10.3) | 10.3 not released |
| Web version in craft CI | `antares_craft/.github/workflows/coverage.yml` | v2.36.0 on `main` (0.17.1 was tested with 2.34.0) | Web at 2.37.0 |
| Craft used by datamanager-generator | `antares-datamanager-generator/requirements.txt` | `antares-craft~=0.17.0` | the next craft minor, with the breaking #448, needs a pin bump |
| antares-study-version | AntaREST and craft `pyproject.toml`; generator `requirements.txt` | 1.0.21; generator 1.0.20 | generator one patch behind |
| antares-timeseries-generation | generator `requirements.txt` | 0.1.9 | - |

A non-empty "Gap" is the drift between producer and consumer. A Simulator minor (such as 10.3) changes several
contracts at once (the "from 10.3" notes in `interactions.md`), so each consumer pinned on the previous one needs an
explicit bump plan.
