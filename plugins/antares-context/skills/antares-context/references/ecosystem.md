# Antares ecosystem

Sources: public READMEs and descriptions of the repositories in github.com/AntaresSimulatorTeam, read 2026-11-17.
User documentation: https://antares-doc.readthedocs.io

## Antares Simulator

Open-source power system simulator developed by RTE (MPL-2.0). It quantifies the adequacy or the economic
performance of interconnected energy systems, at short or remote time horizons. A *study* is a folder on disk
(`study.antares`, `settings/`, `input/`, `output/`).

- `antares-solver`: the command-line simulator. It runs a study in `economy`, `adequacy` or `expansion` mode
  and writes results to `output/`.
- `antares-modeler`: the new dynamic modeler, documented as still under development. Users define the MIP
  variables and constraints of each physical model. A modeler study has `input/model-libraries/`,
  `input/data-series/`, `input/system.yml` and `parameters.yml`.
- Older helper executables (`antares-batchrun`, `antares-config`, `antares-study-finder`, `antares-vacuum`,
  `antares-ybyaggregator`) are documented as deprecated.

## Antares Web (repository: AntaREST)

Web application and REST API for managing and editing Antares Simulator studies, developed by RTE. Documentation:
https://antares-web.readthedocs.io. Studies can live on an Antares Web server instead of a local disk.

## Antares Xpansion

Investment simulations for Antares studies. It works alongside Antares Simulator. Introduction:
https://antares-doc.readthedocs.io/en/latest/reference/xpansion-intro/

## GEMS and GemsPy

- **GEMS** (Generic Energy systems Modelling Schema) is a high-level modelling language and data structure for
  describing energy systems. It is object- and graph-oriented. Docs: https://gems-energy.readthedocs.io
- **GemsPy** is a Python interpreter for GEMS, for modelling and simulating energy systems under uncertainty.
- Converters exist from PyPSA and from Antares legacy models to GEMS.
- A simulator study whose `input/` also contains `system.yml` is a hybrid study: the solver loads the modeler
  components too.

## Python libraries and tools

| Tool | Purpose |
|------|---------|
| antares_craft | Read and edit Antares Simulator studies, on local disk or on an Antares Web server. Trigger simulations and retrieve results |
| antares-study-version | Library and CLI to manage study version numbers, create studies at a given version and upgrade existing studies |
| antares-launcher | Send Antares simulations to a remote Linux machine running SLURM |
| antares-timeseries-generation | Generate time-series input data for Antares studies |
| antares-water-values | Compute water values for Antares |
| antares_data_collection | Read and manage ENTSO-E data files |

## Which tool for which task

| Task | Tool |
|------|------|
| Run a study | `antares-solver`, or Antares Web for a server-managed study |
| Inspect or edit a study from code | antares_craft |
| Upgrade a study to a newer format version | antares-study-version |
| Optimise investments | Antares Xpansion |
| Describe new component models | GEMS, with GemsPy or `antares-modeler` |
| Run many studies on a cluster | antares-launcher, or Antares Web |
