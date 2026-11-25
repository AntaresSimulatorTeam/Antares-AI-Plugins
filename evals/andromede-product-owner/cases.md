# Eval cases: `antares-product:andromede-product-owner`

## 1. Cross-repo impact analysis

- **Prompt:** "We want to rename the columns of the simulation table. What is the impact on the other modules?"
- **Expected:**
  - The skill triggers and loads `references/ecosystem-map.md` and `references/interactions.md`.
  - Identifies contract C4 and its producers (Simulator, GemsPy) and consumers (ViewsBuilder, e2e tests,
    analysts), plus C13 (views read by Antares Web) downstream.
  - Ends with an Ecosystem impact block: per-repo split with owning team, sequencing (GEMS spec first, then both
    interpreters, then consumers and pins), docs to update, open questions with owners.

## 2. Stale or unverifiable facts

- **Prompt:** "Which Simulator version does Xpansion build against today, and can its gems workflow use the
  `price` field of `area-connection`?"
- **Expected:** loads `references/versions.md`; answers with the snapshot value and its date, says it may be stale
  and how to check it (`antares-version.json` on the default branch, or `scripts/ecosystem_status.sh --fetch`).
  Marks anything not read in a primary source as `(to verify)`; doesn't present the snapshot as current fact.

## 3. Writing into a repository

- **Prompt:** "Write a decision record for adding units and dimensional analysis to GEMS, and save it in my
  Antares_Simulator clone."
- **Expected:** loads `references/gems-language.md` and follows workflow A (problem, options including "do
  nothing", comparison, hybrid check, version impact). Notes that a language decision belongs in the GEMS repo
  and asks before writing any file into a clone.

## 4. In-flight work before a spec or brainstorm

- **Prompt:** "Write a spec for exposing the GEMS simulation table in antares_craft." (variant: "Brainstorm how
  users could get sensitivity analysis on GEMS studies.")
- **Expected:**
  - Before writing, searches open issues and PRs across the AntaresSimulatorTeam org with `gh search issues
    ... --owner AntaresSimulatorTeam --state open --include-prs` (or a GitHub tool), using a few keyword sets
    derived from the request.
  - Reads only the few relevant hits and outputs an **In-flight work** table (spec-lens section 7) that
    classifies each one as answers gap / partial overlap / conflict / duplicate.
  - A gap already covered by an open PR becomes a dependency instead of a requirement; a conflict becomes an open
    question with both owner teams. In the brainstorm, open work feeds "Who already does part of it?".
  - If no search is possible, says so, gives the GitHub search link and marks the section `(not checked)`; it
    doesn't invent issues.

## 5. Out of scope

- **Prompt:** "Run my study in ./my-study and tell me if it converges."
- **Expected:** doesn't run anything and doesn't apply the product-owner workflow; says this skill covers product
  work (specs, roadmaps, impact analysis), not running or checking studies.
