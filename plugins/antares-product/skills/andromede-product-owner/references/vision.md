# Long-term vision and strategic tensions (snapshot 2026-11-25)

Sources: `GEMS/README.md`, `GEMS/doc/home/roadmap.md`, `GEMS/doc/home/key-principles.md`,
`antares-xpansion/docs/reference/trajectory-investment/`, repo READMEs and changelogs,
`antares-doc/docs/overview/roadmap.md`. Items marked (interpretation) are the PO lens drawn from those sources,
not official statements: present them as hypotheses to confirm.

## Stated vision (GEMS)

- Build and support a **community of energy modellers and foresight practitioners** who share models, assumptions
  and studies, in a multi-energy, multi-actor world.
- **Versatility**: one generic optimisation language from operational studies to long-term planning,
  multi-carrier, multi-scale.
- **Stability / maintainability**: separate model definition from problem resolution; models evolve without
  touching core code ("getting models out of the code").
- **Interoperability**: self-contained, explicit mathematical formulation -> unambiguous interpretation across
  tools, solvers and frameworks (two interpreters, converters from PyPSA and legacy Antares).

## Public roadmap (GEMS, "a plan, not a promise"; file unchanged since 2026-08-21)

| Horizon | Item | Tag | Ecosystem impact to think about |
|---|---|---|---|
| Now | Custom sets and dimensions (multi-horizon investment, demand response, processes, reserves, piecewise-linear costs) | Language | Both interpreters, hybrid compatibility, Xpansion multi-horizon, outputs shape (simulation table indices), ViewsBuilder |
| Now | ViewsBuilder integration with Simulator and GemsPy | Outputs | C4 / C12 / C13 stability, taxonomy and catalog files, output volume (Parquet), where views run (engine, post-processing or Web, which already reads them) |
| Now | Warm start configuration in GEMS syntax | Solving | Simulator and GemsPy solver layers, Xpansion Benders iterations |
| Next | Weighted connections (flow-based, complex processes) | Language | Hybrid connections to legacy areas, converters |
| Next | Units and dimensional analysis | Language | Library annotation effort, validation in both interpreters, docs |
| Next | Inter-block constraints and dynamics (policy constraints such as security of supply or CO2 targets, in decomposed investment problems) | Language | **Xpansion** decomposition, Simulator blocks/weeks, GemsPy sequential mode |
| Next | Parquet data series | Data | Simulator, GemsPy, converters, Web / craft upload and storage |
| Later | Graphical interface for studies (browse/edit/run, dashboards, maps) | UI | **Relation to Antares Web is an open strategic question**, now sharper since Web stores, launches and displays GEMS studies |
| Later | Hydro pre-processing heuristics (water values) | Solving | Legacy hydro heuristics in Simulator, `antares-water-values` |
| Later | Pareto fronts, sensitivity analysis | Solving | Overlaps the Xpansion sensitivity step |
| Later | Cross-scenario operators (CVaR, cross-scenario equalities) | Language | **Blocked in hybrid** today (hybrid check); fits modeler / GemsPy first |

## User-facing roadmap (antares-doc `overview/roadmap.md`, indicative)

Delivery status per item: `versions.md`. "Thinking about": a heuristic workflow between "accurate" and "fast". This is
the roadmap legacy users read: it and the GEMS Now/Next/Later must stay consistent, and the page is a candidate
update with every release.

## Other module directions

Current state per repo is in `ecosystem-map.md`; this section keeps only the direction.

- **Xpansion**: from annual to **pluriannual trajectory investment** on a scenario tree; GEMS-based problem
  generation; robustness and performance. Natural convergence point with GEMS "multi-horizon investment" and
  "inter-block constraints".
- **Simulator**: hybrid mode as the bridge between legacy and GEMS; modeler for GEMS-only flexibility; simulation
  table and views inputs as post-processing contracts (ADRs `from-GEMS-to-legacy-linear-problem.md`,
  `TimeSeriesVariablesDesign.md`, `Expose_cpp_API.md`); still extending the legacy model.
- **GemsPy**: reference for prototyping new language features.
- **ViewsBuilder**: prototype becoming the standard output and metrics layer for GEMS.
- **Interfaces and generation**: no announced GEMS path for craft or datamanager (to verify with Plateforme and
  Pegase teams); see tension 4.

## Structural tensions to surface in every strategic discussion (interpretation)

1. **Legacy vs GEMS investment balance.** Each legacy-only feature (e.g. thermal ramping, reserves in the legacy
   solver) extends the surface to migrate later. Ask: could this be a GEMS model (library) in hybrid instead of
   hard-coded C++? If not yet, what is missing in GEMS / hybrid?
2. **Two interpreters, one language.** Parity is a permanent cost. Decide per feature: both, GemsPy-first
   (prototype) or Simulator-first (production need). Keep `COMPATIBILITY.md` truthful.
3. **Hybrid constraints vs language ambitions.** Cross-scenario operators and custom horizons collide with the
   hybrid check (`ecosystem-map.md`). Clarify the target: hybrid, modeler or both.
4. **Uneven tooling.** Web now handles GEMS end to end on the back-end side, but craft (and therefore the
   datamanager generator) and Xpansion's study-side tooling remain legacy-only. Scripted and generated studies
   cannot use GEMS through the supported Python API. Each GEMS feature should state its tooling story per interface
   (even "not yet"), and the GEMS "graphical interface" roadmap item should be reconciled with what Web ships.
5. **Outputs fragmentation.** Legacy outputs, simulation tables (two on-disk layouts: Simulator and GemsPy),
   Xpansion outputs, views: avoid N post-processing stacks. Prefer contract-level convergence (simulation table +
   views).
6. **Version drift.** Consumers pin old producer versions and user docs lag releases; see the "Gap" column of
   the pins table in `versions.md`. Release trains and pin bumps are part of the product plan, not dev chores.
7. **Community vs RTE production needs.** Openness (docs, examples, libraries, converters) is a stated goal;
   production robustness (performance, HPC, regression) is RTE's daily constraint. Specs should say which audience
   a feature serves first.

## Vision-fit questions (use in brainstorming and prioritisation)

- Does it move models out of code, or put more model logic into code?
- Does it work the same in GemsPy and Simulator (or is the divergence deliberate and documented)?
- Does it strengthen or fragment the contracts (C1-C13)?
- Does it unlock a roadmap item (custom sets, inter-block, trajectory investment, views integration)?
- What is the tooling and documentation story for end users, per interface?
- What will be hard to undo in 2 years?
