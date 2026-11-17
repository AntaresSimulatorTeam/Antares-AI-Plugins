# Sources et prérequis

- Les paramètres et garde-fous du workflow sont définis dans les scripts fournis : [create-jira-stories.ps1](../scripts/create-jira-stories.ps1) et [configure-jira-pat.ps1](../scripts/configure-jira-pat.ps1).
- Les interfaces Jira REST utilisées sont documentées dans la [référence Jira Server REST API](https://docs.atlassian.com/software/jira/docs/api/REST/).
- Les types, composants et règles propres au projet Antares sont décrits dans [product-repository-component-map.md](product-repository-component-map.md) et [workflow-jira.md](workflow-jira.md). Ils doivent rester conformes à la configuration Jira effective, que le précheck vérifie.

L'accès au Jira Antares et un PAT personnel autorisé sont nécessaires. Windows PowerShell est utilisé sous Windows; sous Linux, PowerShell 7 et un trousseau Secret Service avec `secret-tool` sont nécessaires. Le PAT ne doit jamais être transmis dans une conversation ni placé dans le dépôt.
