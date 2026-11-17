---
name: creer-tickets-jira
description: "Use when asked to create and verify one or more already-framed Antares Jira tickets via the Jira REST API, or to repair explicitly identified mojibake in a ticket created by this workflow."
argument-hint: "Approved proposal(s), target team and Epic key(s)"
---

# Create Antares Jira tickets

This skill uses the Antares Jira API to create already-framed tickets for one team per execution. It does not design the need or choose scope on behalf of the PO.

**Before any action**, read and follow the complete [Jira workflow](references/workflow-jira.md). It contains classification rules, prerequisites, commands, checks and limits, including targeted repair of misencoded text. The `<skill-dir>` paths in that workflow refer to the folder containing this `SKILL.md`.

Consult [product-repository-component-map.md](references/product-repository-component-map.md) to identify the team and Jira component. The required scripts are included in `scripts/`; prerequisites and sources are documented in [sources.md](references/sources.md).

Write ticket content and the preview in French. Never request a PAT in chat. Before creation, run the read-only precheck, present the complete preview, and obtain explicit confirmation. Report verified results and failures without automatically retrying writes.
