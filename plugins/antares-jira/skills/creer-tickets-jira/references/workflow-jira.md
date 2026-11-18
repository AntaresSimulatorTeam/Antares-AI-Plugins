# Create Antares Jira tickets via the API

Create one or more already-framed tickets via the Jira REST API, without opening a browser, for **one team per execution**. The PO owns the backlog: never create another team's tickets merely because they appear in the same conversation or proposal.

This skill creates tickets; it does not design the need, analyze code or repositories, split a need into tickets, choose scope, or invent objectives or acceptance criteria. Use the same workflow regardless of the number of tickets.

## Automatically choose the Jira issue type

Classify each proposal individually without asking the PO to confirm the type:

- **Anomalie** for a correction of an existing malfunction: an incorrect or unexpected result, regression, error, or proven mismatch with expected behavior.
- **User Story** for any functional or technical change that does not correct such a malfunction: new behavior, improvement, adaptation, documentation, refactoring, or another desired change.

Existing documentation that is false, outdated, or contradicts current behavior or the approved contract is also an **Anomalie**, even if the code works as intended. For example, a request to correct a mismatch between the simulator code and the adequacy patch documentation is an `Anomalie`. Use **User Story** to create documentation or change its coverage or structure without correcting incorrect information. If the distinction is unclear, ask only for the necessary clarification about the need, not for confirmation of the issue type.

Show each selected type in the final preview before the single creation confirmation. A batch may include both types.

## Ticket language

Always write all Jira-visible ticket text **in French**, regardless of the proposal or source issue language, including titles, objectives, acceptance criteria, and the preview shown to the PO. Translate English sources into natural, faithful French before preparing JSON. Keep identifiers, proper names, Jira/GitHub keys, repository names, labels, symbols, code excerpts and official names unchanged. Do not change scope or add information.

## Identify ticket proposals

- First look in the current conversation for a conclusion or ticket proposal already formulated and accepted by the PO. Reuse its title, component, objective, criteria, and labels without repeating the analysis; apply the French-language rule.
- The PO may paste the result of another conversation or design skill. Do not assume access to other conversations.
- When a creation request follows a final design proposal in the current conversation, treat it as approval of the proposed scope unless changes are requested or options remain open. Do not restart design or request intermediate scope confirmation; the Jira preview and final confirmation remain mandatory.
- When asked to create a ticket from a GitHub issue, read the issue once and reuse its body. If it contains a coherent core and verifiable changes, use it without running a design skill or seeking intermediate scope confirmation. Handle explicitly stated uncertainty at the relevant criterion rather than rejecting the entire need. Read comments only if the body refers to a necessary discussion or essential information is missing.
- Distinguish a bounded verification from an open functional decision. If the issue explicitly requests verification or validation and names its owner, do not perform it or decide its result: write `À valider par <rôle>` as a criterion and flag it in the preview. If uncertainty may change the objective or core scope, or prevents a testable criterion without assuming an answer, show the established scope and exact open points; ask the PO whether to frame them or retain them as `À valider` criteria. Do not discard already-framed parts.
- An explicit ticket request for an issue primarily about documentation includes that work. Do not confuse this with adding a separate documentation story to a functional batch that did not request one.
- Distinguish accepted proposals from options, assumptions, and brainstorming. If options remain open, ask the PO which to retain.
- Process all retained proposals for the same team together; do not add or discard proposals based on their number.
- If no sufficiently framed proposal exists, do not request a form or create a ticket. Explain that a framed proposal or the conclusion from another conversation is needed before creation.
- If the core need remains incomplete or ambiguous after isolating `À valider` criteria, do not invent answers or precheck undecided scope. Present what is established and the precise blocking decisions; ask only the questions necessary to resolve them.
- Do not suggest manual entry solely because the batch has one to three stories.

## Efficiency

- Aim for at most **five minutes of agent processing** when proposals are ready, the PAT is configured and valid, the team and Epic keys are known, and the API responds normally. Do not promise this for first use; manual PAT creation can take longer.
- Reuse a valid encrypted local PAT. Do not ask for it again.
- Avoid redundant calls: the normal batch precheck already authenticates the PAT, so do not precede it with `-TestConnection`. Preview next, then execute creation once after confirmation. Do not probe other Jira routes manually after a script error.
- Do not read a Jira ticket merely because its key is cited as a reference, historical or deleted ticket. Read one only when explicitly requested and its fields are necessary.
- Follow this procedure without routinely rereading the creation script. If behavior is unexpected, inspect only the relevant script section. Consult the relevant mapping section at most once.
- Do not reload the skill during the same workflow. Prefer structured GitHub tool results. A Copilot output offloaded to a temporary `.txt` is an output capture, not guaranteed JSON: do not parse it with `ConvertFrom-Json` or `ConvertTo-Json`, or run `rg` as a PowerShell command against it. In Copilot use the `rg` file-search tool and `view` on relevant excerpts, with only the exact path in the latest tool output. If it has expired, return to the structured result, not a guessed path. Avoid PowerShell search patterns requiring complex escaping and do not copy the full issue body into a command. Read JSON created by this skill explicitly as UTF-8 before parsing it. Stop if a capture remains ambiguous.
- Do not read Jira again just to find the reporter name; the preview may say the account associated with the PAT. Do not repeat the analysis or rebuild unchanged JSON.

## Team, component, and required information

Infer the owning team from the functional need, affected system, and available technical context. The repository hosting an issue or documentation does not necessarily own the described behavior: an `antares-doc` issue about simulator adequacy patch behavior belongs to team `Simu` and Jira component `Simulateur`.

Use the included [product, repository, and component mapping](product-repository-component-map.md). Ask for a team or component only when evidence is missing, conflicting, or insufficient. Never assume the PO wants tickets for every team.

Create tickets for the selected team only. Exclude other teams, external work without an Antares Jira ticket, contested scope, and unresolved cross-team ownership. Do not add a separate documentation story to a functional batch unless requested; a request primarily about documentation is eligible, with the component inferred from the documented product.

Reuse available information and ask only for missing Jira details:

- One team; infer team and exact component when clear.
- A valid Jira Epic key for the batch or per story. A number supplied by the PO may be normalized to `ANT-<number>`; the precheck must verify that it is an accessible Epic in `ANT`. Never infer or search for an Epic.
- For Plateforme, the approved `backend` or `Frontend` label if not already specified.

The fixed project is `ANT` (displayed as `Antares`). The scripts resolve issue-type IDs and fields from Jira metadata; the PO need not supply technical IDs.

## Jira fields

| Field | Value or rule |
|---|---|
| Project | `ANT` |
| Issue Type | `Anomalie` or `User Story`, selected per ticket and resolved via creation metadata |
| Summary | Approved title |
| Description | Objective/why and acceptance criteria; no theme, dependency or planning |
| Components | Validated component; resolve its exact name to the project ID |
| Labels | Only approved Plateforme labels (`backend` or `Frontend`) |
| Epic Link | PO-provided key, required and verified as an Epic in `ANT` |
| Reporter | Account associated with the PO's PAT, explicitly sent and verified after creation |
| Sprint, Fix Version/s, Release, assignee, status, priority | Do not set |

The scripts resolve metadata separately for each issue type, including the Epic Link field; never hard-code a `customfield_XXXXX`. Any additional required unsupported field blocks the batch before the first write. Temporary JSON and write requests use UTF-8.

## Installation and skill path

Install the entire skill folder, including `SKILL.md`, `scripts/`, and `references/`. Replace `<skill-dir>` in commands with the actual installed folder; do not assume one agent's path applies to another.

| Agent | Skill folder | `<skill-dir>` |
|---|---|---|
| GitHub Copilot in VS Code | Project skill folder, such as `.github/skills/creer-tickets-jira/` | The actual workspace-relative or absolute path |
| Claude Code | Project or personal skill folder, or installed plugin skill | `${CLAUDE_SKILL_DIR}`, resolved by Claude Code when loading the skill |

These instructions target GitHub Copilot in VS Code and Claude Code; do not assume other integrations support skills or scripts. For other GitHub integrations, read an issue only if a GitHub tool is actually available; otherwise ask the PO to paste the necessary content.

## Configure a PAT

- Never request, accept, display, log, or place a PAT in chat, the repository, a script argument, or temporary JSON.
- Scripts detect Windows or Linux at runtime; do not ask the PO to select an OS or remember that choice.
- If the PAT is missing or rejected, ask the PO to create a personal Jira PAT and say when ready, without pasting it in chat. Wait before starting configuration.
- On Windows, run the script with PowerShell. It opens a masked local dialog or supports masked terminal input with `-TerminalPrompt`; it stores the PAT encrypted with DPAPI in the current Windows profile:

  ```powershell
  & (Join-Path '<skill-dir>' 'scripts\configure-jira-pat.ps1')
  & (Join-Path '<skill-dir>' 'scripts\configure-jira-pat.ps1') -TerminalPrompt
  ```

- On Linux, PowerShell 7 (`pwsh`), `secret-tool` (`libsecret-tools`), and an accessible Secret Service keyring are required:

  ```sh
  pwsh -File '<skill-dir>/scripts/configure-jira-pat.ps1'
  ```

  The script uses masked terminal input and stores the PAT in the keyring, not a file. If the tool or keyring is unavailable, stop; never install packages automatically or use a plaintext fallback.
- Configuration validates `/rest/api/2/myself` before storage. An invalid PAT is not stored and does not remove an existing PAT. Each PO uses their own PAT, whose account must be able to browse `ANT` and create issues. Do not bypass permissions or switch to the browser on failure.

## Procedure

1. Identify approved proposals in the current conversation or pasted content. Do not treat exploratory ideas as approved. Stop if none are sufficiently framed.
2. Verify that functional fields are sufficiently precise. Reuse agreed titles, components, objectives, and criteria faithfully, translating ticket text into French. Preserve explicitly assigned validations as `À valider par <rôle>`; stop for open decisions that alter core scope or prevent a testable ticket.
3. Determine the team and exact component from the need. Handle one team per execution; if several teams are involved, ask which to process. Exclude contested scope, unresolved cross-team dependencies, and external work without a Jira ticket. Include explicitly requested documentation work.
4. Briefly present extracted fields, then collect missing component, Epic, and required approved Plateforme label in one exchange. Ask for the Epic after showing the other fields; never search for or choose it.
5. Prepare one local, secret-free UTF-8 JSON file with `issueType`, `summary`, `component`, `objective`, `acceptanceCriteria`, `labels`, and either a batch `epicKey` or per-ticket keys. Set `issueType` automatically to exactly `Anomalie` or `User Story`. Example ticket text remains French:

   ```json
   {
     "epicKey": "ANT-1234",
     "stories": [
       {
         "issueType": "User Story",
         "summary": "Afficher le résultat du calcul",
         "component": "Simulateur",
         "objective": "Présenter le résultat attendu à l'utilisateur.",
         "acceptanceCriteria": ["Le résultat est visible après le calcul."],
         "labels": []
       }
     ]
   }
   ```

   Write **raw JSON**, not a PowerShell `[ordered]@{}` with apostrophe-delimited strings: typographic apostrophes can break PowerShell parsing. Use a literal here-string and UTF-8 without BOM:

   ```powershell
   $jsonText = @'
   <prepared JSON>
   '@
   [System.IO.File]::WriteAllText($jsonPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
   ```

   Retain this file for the whole workflow. The Jira script reads it using `ConvertFrom-Json`.
6. Run the precheck **once** before preview; it is the first Jira call in the normal flow and also checks the PAT:

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <temporary-json> -ValidateOnly
   ```

   On Linux:

   ```sh
   pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <temporary-json> -ValidateOnly
   ```

   The precheck checks authentication, `ANT` creation metadata, selected types and required fields, components, and Epics; it creates nothing. It does not separately read the project. If PowerShell or JSON creation fails, correct that error before calling Jira; do not report a Jira error or successful precheck. For a missing PAT or HTTP 401, follow PAT setup and retry the same precheck once after setup. For other authentication or service errors, stop and report. Correct only identified invalid values or fields before retrying; do not probe unrelated routes or silently substitute values.
7. Present a concise preview for one ticket or the complete list of summaries, types, components, and associated descriptions for a batch. Always include count, team, labels, Epic and expected reporter account. Flag remaining ambiguity; stop if it changes functional content. Obtain **one explicit confirmation** for the whole batch before writing. A changed batch requires a new confirmation.
8. After confirmation, run the creation script **once** with the same JSON and without `-ValidateOnly`. On Linux use `pwsh -File`. The script repeats safeguards immediately before the first POST, creates tickets one by one, then rereads each to verify project, type, summary, description, component, labels, Epic, and reporter. Do not run a separate precheck after confirmation.

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <temporary-json>
   ```

   ```sh
   pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <temporary-json>
   ```

9. Delete temporary JSON in a `finally` block on success or failure; never delete or modify the PAT file.
10. Report verified keys and fields. On partial failure distinguish confirmed tickets from uncertain results. If a POST result is uncertain, search only the relevant summary with a Jira read before deciding; never retry automatically. Report the script's HTTP status and Jira details.

One confirmation authorizes the whole batch; do not ask for each API call. Do not routinely search for duplicates or link tickets. If the PO reports a potential duplicate, verify that case before writing.

## Targeted repair of existing text

Only when the PO explicitly requests correction of a misencoded title or description, use `-RepairExisting` with JSON containing each ticket's `issueKey`, `issueType`, `summary`, `component`, `objective`, `acceptanceCriteria`, `labels`, and Epic. Before modification, the script requires the ticket to belong to `ANT`, match the requested type, Epic, component and PAT reporter, and contain a mojibake marker. Legacy repair files without `issueType` default to `User Story`; always specify the type in new files. It updates only `summary` and `description`, then rereads and verifies both. Never use it to change an Epic or other fields.

```powershell
& (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <temporary-json> -RepairExisting
```

```sh
pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <temporary-json> -RepairExisting
```

## Ticket description

Use exactly these French headings:

```markdown
**Objectif / pourquoi**
<functional or technical outcome and reason for the ticket, in French>

**Critères d'acceptation**
- <observable, testable criterion, in French>
```

Criteria must faithfully reflect the approved breakdown; do not invent missing information. Preserve an explicitly assigned validation as `À valider par <nom/rôle>` and flag it in the preview. For other uncertainty, ask the PO whether to retain it as validation or clarify the need before precheck. For an `Anomalie`, include observed and expected behavior when provided; do not invent either.

## Limits

- Never create tickets before explicit preview confirmation.
- Do not choose an Epic, team, component, or label when evidence does not establish it; normalize a PO-provided Epic number and verify the resulting key.
- Do not open the integrated browser or modify an Epic or other fields beyond explicitly requested targeted text repair.
- If Jira rejects a field, access is missing, or created-ticket verification fails, stop, preserve already-created tickets, and report the exact state.
- On HTTP 404 `Issue Does Not Exist` when reading an Epic, create nothing and do not guess or search for another. Explain that the key is missing or inaccessible to the PAT account and ask the PO for a valid, visible Epic before retrying.
