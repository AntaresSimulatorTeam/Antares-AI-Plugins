# Specification lens: checklist and templates

Use with `product-management:write-spec` (append the Ecosystem impact block to its PRD) or standalone: sections 3
to 6 are enough to produce an epic, stories, a brainstorm or a prioritisation without any other skill.

## 1. Cross-module impact checklist (run before writing)

For each line answer Yes / No / Unknown (Unknown -> open question with owner).

| Area | Question |
|---|---|
| GEMS language | New/changed syntax, semantics, file (library/system/optim-config/taxonomy/catalog/view-config)? Language version bump (patch/minor/major)? |
| GEMS libraries | Any of basic / andromede / antares_legacy / pypsa models change? Library version + CHANGELOG + sha256? |
| GemsPy | Implementation needed? Parity with Simulator? PyPI release? |
| Simulator legacy | Legacy solver behaviour or study format change? Study version + migration guide? |
| Simulator hybrid | Works with legacy areas connections, MC per scenario, LP/MILP, horizon/resolution? Outputs (legacy + simulation table) coherent? |
| Simulator modeler | Needed or explicitly out of scope? |
| Xpansion | Affects MPS/problem structure, candidates, gems workflow (optim-config), trajectory investment, Benders performance? |
| ViewsBuilder | Simulation table columns/semantics or layout, `system-for-views.yml`, taxonomy, catalogs, view-config, views output naming? |
| antares_craft | New object/property to expose? Local and API backends both? |
| AntaREST | UI, variant commands, study upgrade, results view, launcher config, API change? GEMS storage (DB schema, round trip of GEMS files), hybrid launch, GEMS views reader? |
| antares-launcher | New binary, version detection, cluster resources? |
| antares-datamanager | Study JSON (C11) or generated study (C1) change? Craft pin bump? Should generation produce it (GEMS / hybrid path)? |
| Converters | Legacy->GEMS / PyPSA->GEMS output still valid? New mapping needed? Converter libraries, catalogs and view configs? |
| Docs | Repo technical docs, antares-doc (user: release-notes feed, tutorial/reference page, roadmap line; nav entry in `mkdocs.yml`), GEMS docs + release notes, migration guides, changelogs? |
| Tests | GEMS e2e validation, Simulator ctest + run-study-tests, GemsPy pytest, Xpansion tests, Web/craft tests, reference results to update? |
| Versions/pins | Which pins must move (dependencies.json, COMPATIBILITY.md, antares-version.json, pyproject pins, requirements; list in versions.md)? In what order? |
| Performance/HPC | Problem size, solve time, memory, cluster usage? |

## 2. Ecosystem impact block (append to every spec / epic / decision record)

```markdown
## Ecosystem impact

**Primary repo:** <repo>   **Users:** <modeller | Web user | Python scripter | operator | dev team>
**Path:** legacy | GEMS (hybrid / modeler / GemsPy) | both   **Roadmap horizon:** Now | Next | Later | off-roadmap (justify)

| Repo | Impact | Change type | Sibling issue |
|---|---|---|---|
| GEMS (spec/libraries/docs) | none / docs / feature / breaking | ... | to create |
| GemsPy | | | |
| Antares_Simulator (legacy / hybrid / modeler) | | | |
| antares-xpansion | | | |
| GEMS-ViewsBuilder | | | |
| antares_craft | | | |
| AntaREST | | | |
| antares-launcher | | | |
| antares-datamanager | | | |
| Converters | | | |
| antares-doc | | | |

**In-flight work:** <see section 7, or "none found for <keywords>", or "(not checked)">
**Contracts touched:** C<n> <name>: <what changes> (see interactions.md)
**Compatibility:** backward compatible? version bumps (language x.y.z, study version, packages). Migration path for existing studies/models.
**Sequencing:** 1. <repo> ... 2. <repo> (needs pin bump) ... 3. docs/tooling
**Vision check:** <how this moves toward/away from the long-term direction; what it makes easier/harder later>
**Open questions:** <question> - owner <team>
```

## 3. Epic split pattern

One epic, N repo-scoped stories, explicit order:

```markdown
# Epic: <outcome for the user>
Outcome: as a <user>, I can <capability> in <hybrid study | GemsPy | Antares Web | ...>.

1. [GEMS] Spec + example + e2e test skeleton            -> unblocks 2, 3
2. [GemsPy] Implement + tests                           (parallel with 3)
3. [Antares_Simulator] Implement in hybrid (+ modeler?) + tests
4. [GEMS] Bump COMPATIBILITY.md / dependencies.json, enable e2e on both interpreters
5. [antares-xpansion | ViewsBuilder] Adapt consumer if contract touched
6. [antares_craft / AntaREST] Expose (or explicit "not yet" + issue)
7. [antares-doc / GEMS docs] User documentation, migration guide, release notes
Definition of done for the epic: <end-to-end user scenario, testable>
```

## 4. Story template (repo-scoped)

```markdown
## <verb + outcome>
**Repo:** <one repo>  **Team:** <owning team, see ecosystem-map.md>  **Epic:** <link>  **Depends on:** <issues>  **User:** <who>

### Problem
As a <user>, I need <capability> so that <outcome>. Today: <current behaviour / workaround>.

### Scope
In: ...   Out: ... (incl. other repos explicitly deferred)

### Acceptance criteria
1. Given <concrete input: study snippet / YAML / API call>, when <action>, then <observable result>.
2. Test added in <repo harness>.
3. Docs updated: <page>.

### Contract & compatibility
Contract(s): ...  Backward compatible: yes/no. Version impact: ...

### Size / priority
S|M|L - one-line rationale (user value, unblocking effect, risk reduction).
```

## 5. Brainstorm framing (add to `product-management:product-brainstorming` output, or use alone)

- **Where could this live?** Generate at least one option per plausible layer (language/library, engine, planning, interface, post-processing) and compare on: user value, contract impact, parity cost, tooling story, vision fit, reversibility.
- **Who already does part of it?** (e.g. Xpansion sensitivity vs GEMS Pareto/sensitivity; legacy hydro heuristics vs GEMS hydro pre-processing; Web results vs ViewsBuilder.) Include open issues and PRs from the in-flight scan (section 7): an option that an open PR already implements is cheaper, and one that contradicts it needs a conversation first.
- **What would make this a GEMS model instead of code?**
- **Kill criteria**: what evidence would make us drop it.

## 6. Prioritisation criteria (ecosystem-weighted)

Score 1-5, then discuss, never sum blindly:
User value | Vision fit / roadmap unlock | Contract risk (inverse) | Parity & multi-repo cost (inverse) | Unblocking effect on other teams | Risk reduction (de-risk C++ architecture or hybrid constraints early) | Reversibility.

## 7. In-flight work (open issues and PRs)

Built from the scan in SKILL.md Step 2. Put it before the scope in a spec, and in "Who already does part of it?"
in a brainstorm.

```markdown
## In-flight work
Searched: org AntaresSimulatorTeam, open issues + PRs, <date>, keywords: "<set 1>", "<set 2>"

| Item | Repo | Kind / status | Relation | Effect on this spec |
|---|---|---|---|---|
| #123 <title> | GemsPy | PR, open, updated <date> | answers gap | <criterion X> removed from scope; dependency: merge #123 first |
| #456 <title> | Antares_Simulator | issue, open | partial overlap | reuse as sibling issue; extend its acceptance criteria |
| #789 <title> | antares-xpansion | PR, draft | conflict | open question: <contract shape> - owners <team A> + <team B> |
```

Relations: **answers gap** (becomes a dependency, leaves the scope), **partial overlap** (reuse or extend, don't
duplicate), **conflict** (open question with both owner teams), **duplicate** (comment on the existing issue
instead of creating one). Only list items you actually read; say "none found" when the search returned nothing
relevant.
