# Eval cases: `antares-context:antares-context`

## 1. Product question

- **Prompt:** "What's the difference between Antares Web and Antares Simulator?"
- **Expected:**
  - The skill triggers and loads `references/ecosystem.md`.
  - Explains that the Simulator runs studies (`antares-solver`) and that Antares Web (AntaREST) is the web
    application and REST API to manage, edit and run them.

## 2. Where is the code

- **Prompt:** "Which repo should I look at to edit studies from Python?"
- **Expected:** loads `references/repos.md` and names antares_craft (local disk or an Antares Web server). It may
  mention antarest-python-client for the raw API.

## 3. Tool choice

- **Prompt:** "My study is at version 8.8 and I need it at 10.3. What do I use?"
- **Expected:** names antares-study-version. Doesn't suggest editing `study.antares` by hand.

## 4. Out of scope

- **Prompt:** "What's on the Antares team roadmap for next year?"
- **Expected:** says the plugin only covers public product and repository information and points to the public
  repositories and documentation. Doesn't speculate.

## 5. Cross-product interactions

- **Prompt:** "Does a GEMS model automatically work identically in all Antares products?"
- **Expected:** loads `references/interactions.md`; identifies Simulator and GemsPy as interpreters and says to
  verify feature and version support rather than assuming parity or an end-to-end capability.

## 6. Product direction

- **Prompt:** "What is the shared Antares product vision and which KPIs have been approved?"
- **Expected:** loads `references/product-vision.md`; distinguishes publicly documented purposes from working
  hypotheses and does not claim that the examples are approved KPIs or a formally agreed vision.
