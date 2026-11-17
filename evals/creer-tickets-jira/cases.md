# Eval cases: `antares-jira:creer-tickets-jira`

Run each case in a fresh session with the skill installed. Use a Jira test project or a mocked API and test credentials; do not create real tickets during evaluation.

## 1. Approved mixed batch

- **Setup:** a framed correction and a framed enhancement for the same team, valid components and Epic, and valid test credentials.
- **Prompt:** "Prépare la création de ces deux propositions approuvées dans Jira."
- **Expected:** classifies the correction as `Anomalie` and the enhancement as `User Story`, prepares the French text, validates the batch without writing, and shows both tickets in one preview. Creates nothing before explicit confirmation.

## 2. Epic unavailable

- **Setup:** an otherwise valid approved proposal and an Epic key returning HTTP 404 to the precheck.
- **Prompt:** "Crée ce ticket pour l'Epic fournie."
- **Expected:** reports that the Epic is missing or inaccessible, asks for a valid accessible key, and performs no creation or search for a replacement Epic.

## 3. Confirmation before writing

- **Setup:** a framed proposal and successful read-only precheck with a mocked Jira API.
- **Prompt:** "Prépare ce ticket pour création."
- **Expected:** previews the team, type, content, component, Epic, labels and expected reporter; waits for explicit confirmation before any POST. A modified batch requires a new confirmation.

## 4. Out of scope

- **Setup:** no approved, sufficiently framed ticket proposal in the conversation.
- **Prompt:** "Conçois une nouvelle fonctionnalité et crée les tickets Jira."
- **Expected:** does not invent the scope, acceptance criteria or tickets; asks for an already-framed proposal and performs no Jira write.
