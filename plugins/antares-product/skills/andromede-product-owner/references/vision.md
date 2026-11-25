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
| Now | ViewsBuilder integration with Simulator and GemsPy | Outputs | C4 / C12 / C13 stability, taxonomy and catalog files, output volume (Parquet), where views run (engine, post-processing or Web: Web 2.37 already reads them) |
| Now | Warm start configuration in GEMS syntax | Solving | Simulator and GemsPy solver layers, Xpansion Benders iterations |
| Next | Weighted connections (flow-based, complex processes) | Language | Hybrid connections to legacy areas, converters |
| Next | Units and dimensional analysis | Language | Library annotation effort, validation in both interpreters, docs |
| Next | Inter-block constraints and dynamics (policy constraints such as security of supply or CO2 targets, in decomposed investment problems) | Language | **Xpansion** decomposition, Simulator blocks/weeks, GemsPy sequential mode |
| Next | Parquet data series | Data | Simulator, GemsPy, converters, Web / craft upload and storage |
| Later | Graphical interface for studies (browse/edit/run, dashboards, maps) | UI | **Relation to Antares Web is an open strategic question**, now sharper since Web stores, launches and displays GEMS studies |
| Later | Hydro pre-processing heuristics (water values) | Solving | Legacy hydro heuristics in Simulator, `antares-water-values` |
| Later | Pareto fronts, sensitivity analysis | Solving | Overlaps the Xpansion sensitivity step |
| Later | Cross-scenario operators (CVaR, cross-scenario equalities) | Language | **Blocked in hybrid** today (each MC scenario optimised separately); fits modeler / GemsPy first |

## User-facing roadmap (antares-doc `overview/roadmap.md`, indicative; page unchanged since 2026-06-04)

Listed as "working on", with the delivery status found in the repos on 2026-11-25:

| Item | Status in the repos |
|---|---|
| Reserves model (FCR, aFFR, mFRR, RR) | Shipped in Simulator 10.2 and Web; scenarised reserve needs in Simulator 10.3 (rc): candidate to move to "delivered" |
| **GEMS models in hybrid studies, usable with Craft and Web** | Web: storage, API and hybrid launch (2.36-2.37). Craft: not started |
| Investment on objects (not only links) | No release yet; the legacy converter added an investment-candidates GEMS library (to verify the link) |
| Thermal ramp parameters | Simulator 10.3 (rc); Web gates ramp settings on study version 10.3 |
| New open-source solver to replace Sirius | Not traced in this snapshot (to verify) |
| Parquet outputs | Done for modeler and legacy simulation tables in Simulator 10.2; still listed |

"Thinking about": a heuristic workflow between "accurate" and "fast". This is the roadmap legacy users read: it and
the GEMS Now/Next/Later must stay consistent, and the page is a candidate update with every release.

## Other module directions

- **Xpansion**: from annual investment to **pluriannual trajectory investment** on a scenario tree; GEMS-based
  problem generation (`gems` step, optim-config); robustness (robust resume) and performance (micro-iterations,
  skeleton subproblems). Natural convergence point with GEMS "multi-horizon investment" and "inter-block
  constraints".
- **Simulator**: hybrid mode as the bridge between legacy and GEMS; modeler for GEMS-only flexibility; simulation
  table and views inputs as post-processing contracts (ADRs `from-GEMS-to-legacy-linear-problem.md`,
  `TimeSeriesVariablesDesign.md`, `Expose_cpp_API.md`); still extending the legacy model (reserves, thermal ramping).
- **GemsPy**: maintained Python interpreter, sequential mode, programmatic study building, disk-backed simulation
  tables; reference for prototyping new language features (power operator, integer strategy, heuristics).
- **ViewsBuilder**: prototype becoming the standard output and metrics layer for GEMS (taxonomy + catalog +
  view-config), now consumed by Antares Web.
- **Antares Web / craft / launcher**: Web is the first interface with real GEMS support (storage, API, hybrid
  launch, views display); craft has none; launcher is GEMS-agnostic.
- **antares-datamanager**: legacy-only generation; no announced GEMS path (to verify with the Pegase team).

## Structural tensions to surface in every strategic discussion (interpretation)

1. **Legacy vs GEMS investment balance.** Each legacy-only feature (e.g. thermal ramping, reserves in the legacy
   solver) extends the surface to migrate later. Ask: could this be a GEMS model (library) in hybrid instead of
   hard-coded C++? If not yet, what is missing in GEMS / hybrid?
2. **Two interpreters, one language.** Parity is a permanent cost. Decide per feature: both, GemsPy-first
   (prototype) or Simulator-first (production need). Keep `COMPATIBILITY.md` truthful.
3. **Hybrid constraints vs language ambitions.** Cross-scenario operators, scenario-independent variables, custom
   horizons collide with the legacy MC-per-scenario structure. Clarify the target: hybrid, modeler or both.
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
