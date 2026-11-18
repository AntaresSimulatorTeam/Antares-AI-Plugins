# Product interactions and shared formats

This is a non-exhaustive orientation map, not a guarantee of compatibility between versions or deployments.
Check the documentation and actual versions before making implementation or integration decisions.

## Antares studies

- Antares Simulator runs studies; Antares Web provides a web interface and API for managing and editing studies
  ([Simulator](https://github.com/AntaresSimulatorTeam/Antares_Simulator),
  [Antares Web](https://github.com/AntaresSimulatorTeam/AntaREST)).
- Antares Craft accesses studies on disk or on an Antares Web server, can launch simulations and retrieve
  results ([Antares Craft](https://github.com/AntaresSimulatorTeam/antares_craft)).
- The data manager backend describes exposing stored data for study generation; the generator describes
  producing Antares studies ([backend](https://github.com/AntaresSimulatorTeam/antares-datamanager-back/blob/develop/README.md),
  [generator](https://github.com/AntaresSimulatorTeam/antares-datamanager-generator)).
- Antares Xpansion performs investment simulations alongside Antares Simulator
  ([Antares Xpansion](https://github.com/AntaresSimulatorTeam/antares-xpansion)).

These are alternative and complementary ways to use or produce studies, not a required linear workflow.

## GEMS inputs and results

- [GEMS](https://github.com/AntaresSimulatorTeam/GEMS) defines a modelling language and data structure;
  Antares Simulator and [GemsPy](https://github.com/AntaresSimulatorTeam/GemsPy) are listed as interpreters.
  Their implementations are independent; check feature and version support rather than assuming parity.
- [GEMS Views Builder](https://github.com/AntaresSimulatorTeam/GEMS-ViewsBuilder) describes consuming GEMS
  simulation tables produced by either interpreter and creating aggregated views.
- A change may affect model definitions, study files, APIs, simulation tables or execution separately. Identify
  the specific format and the producers and consumers involved; do not treat all outputs as one contract.

## Questions for an impact analysis

1. Which product and user entry point are affected?
2. Which format, API, input or output is changing, and which products actually consume it?
3. Which versions, integrations, tests and documentation need checking?

A feature available in one component is not automatically exposed by every interface or supported by every
deployment. Validate the specific end-to-end path instead of assuming it.
