# Sources and prerequisites

- Workflow parameters and safeguards are implemented in the included [create-jira-stories.ps1](../scripts/create-jira-stories.ps1) and [configure-jira-pat.ps1](../scripts/configure-jira-pat.ps1).
- Jira REST interfaces are documented in the [Jira Server REST API reference](https://docs.atlassian.com/software/jira/docs/api/REST/).
- Antares-specific types, components and rules are described in [product-repository-component-map.md](product-repository-component-map.md) and [workflow-jira.md](workflow-jira.md). The precheck verifies their compatibility with the actual Jira configuration.

Access to Antares Jira and an authorized personal PAT are required. Windows uses Windows PowerShell; Linux requires PowerShell 7 and a Secret Service keyring with `secret-tool`. Never send the PAT in a conversation or place it in the repository.
