---
name: creer-ou-modifier-tickets-jira
description: "Create, verify, repair or update Jira tickets in Antares through the Jira REST API, without using the integrated browser. Create Anomalie, User Story or Technical Stories tickets from an approved proposal, repair mojibake, or rewrite the description (and optionally title or labels) of an existing ticket of any type from a pasted text or a Confluence page read with the Jira PAT."
argument-hint: "Proposition(s) validée(s), équipe cible, clé(s) Epic ou clé de ticket à mettre à jour (+ spec ou URL Confluence)"
---

# Créer des tickets Jira Antares par API

Créer un ou plusieurs tickets déjà cadrés au moyen de l'API REST Jira, sans ouvrir de navigateur et pour **une seule équipe par exécution**. Le PO reste maître de son backlog : ne jamais créer les tickets d'une autre équipe simplement parce qu'ils figurent dans la même conversation ou proposition.

Cette skill crée des tickets; elle ne conçoit pas le besoin. Elle ne fait pas d'analyse de code ou de dépôts, ne découpe pas un besoin en tickets, ne choisit pas le scope et n'invente ni objectifs ni critères d'acceptation. Le nombre de tickets ne détermine pas un mode différent : appliquer le même parcours à un ticket ou à plusieurs.

## Choisir automatiquement le type Jira

Classer chaque proposition individuellement, sans demander au PO de confirmer son type :

- **Anomalie** si le besoin corrige un dysfonctionnement d'un comportement existant : résultat incorrect ou inattendu, régression, erreur, ou écart avéré avec le comportement attendu.
- **User Story** pour toute évolution qui ne corrige pas un tel dysfonctionnement et qui débloque de la valeur utilisateur, qu'elle soit fonctionnelle ou technique débloquant une valeur : nouveau comportement, amélioration, adaptation, documentation ou autre changement souhaité.
- **Technical Stories** pour le travail purement technique qui ne débloque aucune valeur utilisateur : refactorisation, suppression de code, nettoyage ou autre tâche interne. Une tâche technique qui débloque une valeur reste une **User Story**.

Une documentation existante fausse, obsolète ou contradictoire avec le comportement actuel ou le contrat approuvé constitue aussi une **Anomalie** à corriger, même si le code fonctionne comme prévu. Ainsi, l'écart entre le code du simulateur et la documentation de l'adequacy patch est une `Anomalie` lorsque la demande consiste à corriger cette documentation. Utiliser **User Story** pour créer de la documentation ou en faire évoluer la couverture ou la structure sans corriger une information erronée. Si les éléments disponibles ne permettent pas de distinguer correction d'une erreur et évolution souhaitée, demander uniquement la précision nécessaire sur le besoin, pas une confirmation du type.

Afficher le type retenu pour chaque ticket dans l'aperçu final avant l'unique confirmation de création. Un lot peut contenir les deux types.

## Langue des tickets

Rédiger systématiquement en français tout le texte visible des tickets Jira, quelle que soit la langue de la proposition ou de l'issue source, y compris les titres, objectifs, critères d'acceptation et l'aperçu présenté au PO. Si la source est en anglais, la traduire en français naturel et fidèle avant de préparer le JSON; ne pas conserver des phrases anglaises simplement parce qu'elles viennent d'une issue GitHub.

Conserver tels quels les identifiants, noms propres, clés Jira/GitHub, noms de dépôts, labels, symboles, extraits de code et libellés officiels qui doivent rester exacts. La traduction ne doit ni modifier le périmètre ni ajouter d'information.

## Identifier les propositions de tickets

- Chercher d'abord dans la conversation courante une conclusion ou une proposition de ticket déjà formulée et retenue par le PO. Réutiliser les informations disponibles (titre, composant, objectif, critères, labels) sans refaire l'analyse qui les a produites; appliquer la règle de langue ci-dessus aux textes destinés à Jira.
- Le PO peut aussi coller le résultat d'une autre conversation ou d'une autre skill de conception. Cette skill ne peut pas supposer qu'elle a accès aux autres conversations.
- Dans le parcours habituel, si le PO demande la création à la suite d'une proposition finale de conception dans la conversation courante, considérer cette demande comme la validation du cadrage proposé, sauf s'il demande une modification ou si des options restent ouvertes. Réutiliser la proposition sans relancer la conception ni demander une confirmation intermédiaire du périmètre; l'aperçu Jira et sa confirmation finale restent obligatoires.
- Lorsqu'un PO demande de créer un ticket à partir d'une issue GitHub, lire l'issue une seule fois et réutiliser son corps. Si elle décrit un noyau cohérent et des changements vérifiables, s'en servir comme base sans lancer une skill de conception ni demander une confirmation intermédiaire du cadrage. Une incertitude explicitement signalée dans l'issue ne rend pas automatiquement tout le besoin inexploitable : la traiter au niveau du critère concerné, selon les règles ci-dessous. Lire les commentaires seulement si le corps renvoie à une discussion nécessaire ou si une information indispensable manque.
- Distinguer une vérification bornée d'une décision fonctionnelle ouverte. Si l'issue demande explicitement une vérification ou une validation et en nomme le responsable, ne pas effectuer soi-même cette vérification ni décider de son résultat : la formuler comme un critère `À valider par <rôle>` et signaler ce point dans l'aperçu. Si l'incertitude peut changer l'objectif ou le périmètre central, ou empêche de formuler un critère testable sans supposer la réponse, exposer le périmètre déjà établi et les points précis à trancher; demander au PO s'il veut les faire cadrer ou les conserver comme critères `À valider`. Ne pas rejeter en bloc les parties déjà cadrées.
- Une demande explicite de tickets pour une issue dont le travail principal est documentaire inclut ce travail dans le périmètre. Ne pas confondre ce cas avec l'ajout d'une story documentaire distincte à un lot fonctionnel qui ne la demande pas.
- Distinguer une proposition retenue des options, hypothèses ou pistes de brainstorming. Si plusieurs possibilités restent ouvertes, ne pas décider lesquelles deviennent des tickets; demander au PO lesquelles il retient.
- Si plusieurs stories déjà proposées sont retenues, les traiter ensemble lorsqu'elles relèvent de la même équipe. Ne pas en écarter ou en ajouter en fonction de leur nombre.
- Si aucune proposition suffisamment cadrée n'est identifiable, ne pas demander au PO de remplir un formulaire et ne pas créer de ticket. Répondre par exemple : « Je ne vois pas dans cette conversation de proposition de ticket suffisamment cadrée. Utilise une skill de conception pour préciser le besoin, ou colle ici la conclusion d'une autre conversation. Je pourrai ensuite préparer la création du ou des tickets Jira. »
- Si le noyau fonctionnel reste incomplet ou ambigu après avoir isolé les critères `À valider`, ne pas inventer de réponse ni lancer le précheck sur un périmètre indécis. Présenter les éléments déjà cadrés et les décisions précises qui bloquent; inviter le PO à les faire préciser par une skill de conception ou à confirmer qu'ils restent des critères `À valider`. Ne poser que les questions nécessaires pour lever ce blocage, pas pour refaire la conception.
- Ne pas avertir qu'une saisie manuelle serait préférable uniquement parce qu'il y a une à trois stories. L'appel explicite de la skill signifie que le PO souhaite utiliser ce parcours.

## Objectif de fluidité

- Viser **5 minutes maximum de traitement par l'agent** lorsque la ou les propositions sont prêtes, que le PAT est déjà configuré et valide, que l'équipe et les Epic(s) sont connus, et que l'API répond normalement.
- Ne pas promettre ce délai pour une première utilisation : la création manuelle du PAT dans Jira dépend du PO et peut dépasser 5 minutes.
- Réutiliser le PAT local chiffré. Ne jamais le redemander s'il est valide.
- Éviter les appels redondants : dans le parcours normal, le précheck du lot authentifie déjà le PAT; ne pas le précéder d'un `-TestConnection`. Présenter ensuite l'aperçu, puis exécuter une seule fois la création après confirmation. Ne pas sonder manuellement d'autres routes Jira si le script retourne une erreur.
- Ne pas lire un ticket Jira simplement parce que sa clé est citée comme référence, historique ou ticket supprimé. Réutiliser la proposition ou l'issue source; ne lire un ticket existant que si le PO le demande explicitement (correction ou mise à jour) et que ses champs sont nécessaires à cette demande.
- Suivre la procédure et les champs décrits dans cette skill sans relire systématiquement le script de création. En cas d'erreur ou de comportement inattendu, inspecter uniquement la partie pertinente du script. Pour la cartographie, consulter au plus une fois la section utile; utiliser une recherche ciblée et une plage de lignes plutôt que tenter de lire entièrement un fichier volumineux.
- Après le chargement de la skill, ne pas la relire ni la charger une seconde fois dans le même parcours. Utiliser d'abord le résultat structuré de l'outil GitHub. Si une sortie Copilot est déportée dans un fichier temporaire `.txt`, la traiter comme une capture de sortie, pas comme un payload JSON garanti, même si elle semble commencer par `{` ou `[`. Ne pas la parser avec `ConvertFrom-Json` ou `ConvertTo-Json`, et ne pas lancer `rg` comme une commande PowerShell sur cette capture. Dans Copilot, utiliser l'outil de recherche de fichiers `rg` avec ses arguments `pattern` et `paths` (pas une commande terminal); lire les extraits utiles avec `view`. Utiliser uniquement le chemin exact fourni par la sortie d'outil la plus récente : ces fichiers temporaires peuvent expirer ou changer de nom. Si le chemin n'existe plus, ne pas réessayer avec un chemin deviné ou ancien; revenir au résultat structuré de l'outil. Éviter les motifs de recherche nécessitant des échappements de guillemets ou de barres obliques inverses dans PowerShell. Ne pas recopier le corps complet dans une commande. Pour un JSON créé directement par la skill, le lire explicitement en UTF-8 (`[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)`) avant de le parser. Si une capture d'outil reste ambiguë, s'arrêter plutôt que de deviner sa structure ou de la réparer automatiquement.
- Ne pas lancer de lecture Jira supplémentaire pour retrouver le nom du reporter : l'aperçu peut indiquer « compte associé au PAT ».
- Ne pas refaire l'analyse, le découpage ni reconstruire plusieurs fois le JSON si le contenu retenu n'a pas changé.

## Équipe cible et composants

Déduire l'équipe propriétaire à partir du besoin fonctionnel, du système concerné et du contexte technique disponible. Ne pas confondre le dépôt qui héberge l'issue ou la documentation avec le propriétaire du comportement décrit : par exemple, une issue dans `antares-doc` portant sur le comportement de l'adequacy patch relève clairement de l'équipe Simu et du composant Jira `Simulateur`. Dans Jira, `Simu` désigne l'équipe; la valeur exacte du composant est `Simulateur`.

Utiliser la [référence produits, dépôts et composants](./references/product-repository-component-map.md) incluse avec cette skill. Cette référence contient uniquement les correspondances nécessaires à la création Jira; elle remplace toute dépendance à la cartographie générale du workspace.

La référence incluse définit les composants Jira exacts et leur correspondance avec les équipes et dépôts. Demander l'équipe ou le composant uniquement si les indices sont absents, contradictoires ou ne permettent pas une attribution fiable. Ne jamais supposer que le PO veut créer les stories de toutes les équipes.

Créer seulement les stories de l'équipe choisie. Exclure les stories d'autres équipes, le travail externalisé sans ticket Jira et toute responsabilité interéquipes encore indécise. Ne pas ajouter une story documentaire distincte à un lot fonctionnel sans demande explicite; en revanche, une issue ou une demande explicitement consacrée à la documentation est admissible, avec le composant déduit du produit documenté plutôt que du seul dépôt `antares-doc`.

## Informations nécessaires

Réutiliser les informations présentes dans la proposition retenue; ne pas les redemander. Recueillir uniquement les éléments Jira manquants :

- une seule équipe pour l'exécution; déduire l'équipe et le composant Jira exacts du besoin et de son contexte lorsqu'ils sont clairs, et ne demander que si l'attribution reste ambiguë;
- une clé d'Epic Jira valide, commune au lot ou fournie story par story si les rattachements diffèrent; un numéro seul peut être normalisé en clé du projet `ANT`;
- pour Plateforme, le label validé `backend` ou `Frontend` si la proposition ne le précise pas.

Le composant, le titre, l'objectif et les critères peuvent être extraits de la proposition de conception et de son contexte. Déduire le composant du domaine fonctionnel même s'il n'est pas nommé dans l'issue; par exemple, une demande de documentation décrivant le comportement du simulateur peut relever de `Simulateur`, même si elle est ouverte dans le dépôt `antares-doc`. Demander le composant uniquement si ce contexte ne permet pas de trancher.

La clé Epic peut manquer à l'appel initial, mais **elle est obligatoire avant toute création**. Le projet Jira étant fixé à `ANT`, accepter aussi un numéro seul fourni par le PO et le normaliser en `ANT-<numéro>` avant le précheck (par exemple `5219` devient `ANT-5219`). Cette normalisation ne choisit pas l'Epic : le précheck doit confirmer que la clé existe et désigne une Epic du projet `ANT`. Ne pas déduire un numéro d'Epic du contexte, chercher une Epic dans la roadmap ou créer de story sans Epic valide.

Le projet `ANT` (affiché `Antares`) est fixe. Le type est déterminé automatiquement pour chaque ticket selon les règles ci-dessus. Le PO n'a pas à fournir d'identifiants techniques d'API, d'ID de composant ou de nom de champ personnalisé : les scripts les résolvent à partir des métadonnées Jira.

## Champs Jira

| Champ Jira | Valeur à envoyer ou règle |
|---|---|
| Project | `ANT`, clé fixe du projet Jira |
| Issue Type | `Anomalie`, `User Story` ou `Technical Stories`, choisi automatiquement en création et résolu en ID via les métadonnées de création. En mise à jour, le type existant du ticket est conservé, quel qu'il soit |
| Summary | Titre approuvé |
| Description | Objectif/pourquoi et critères d'acceptation, sans thème, dépendance ni planification |
| Components | Composant validé; nom exact résolu en ID du projet |
| Labels | Uniquement ceux validés pour Plateforme (`backend` ou `Frontend`) |
| Epic Link | Clé d'Epic fournie par le PO, obligatoire et vérifiée comme Epic du projet `ANT` |
| Reporter | Compte Jira associé au PAT du PO, envoyé explicitement par le script et vérifié après création |
| Sprint, Fix Version/s, Release, assignee, statut, priorité | Ne pas définir |

Les scripts utilisent les métadonnées projet-spécifiques de l'API Jira pour résoudre le type et les champs de chaque ticket. Le champ technique Epic Link peut avoir un ID différent selon l'instance; le script l'identifie via les métadonnées et confirme qu'il est disponible pour chaque type sélectionné. Ne jamais coder en dur un `customfield_XXXXX`. Tout champ obligatoire supplémentaire non géré bloque le lot avant la première écriture. Le JSON temporaire est lu explicitement en UTF-8 et les requêtes d'écriture sont envoyées en octets UTF-8, y compris pour les titres et descriptions accentués.

## Installation selon l'agent

Le dossier complet de la skill comprend `SKILL.md`, `scripts/` et `references/`. Installer ou copier le même dossier selon l'agent utilisé :

| Agent | Emplacement du dossier de la skill | Comment résoudre `<skill-dir>` dans les commandes ci-dessous |
|---|---|---|
| GitHub Copilot dans VS Code | `.github/skills/creer-ou-modifier-tickets-jira/` à la racine du workspace | Chemin workspace-relatif `.github/skills/creer-ou-modifier-tickets-jira` |
| Claude Code | `.claude/skills/creer-ou-modifier-tickets-jira/` à la racine du projet, ou `~/.claude/skills/creer-ou-modifier-tickets-jira/` pour une installation personnelle | Utiliser `${CLAUDE_SKILL_DIR}`; Claude Code remplace ce marqueur par le chemin réel du dossier de la skill lorsqu'il la charge |

Dans les exemples, `<skill-dir>` est un placeholder : le remplacer par le chemin correspondant à l'agent avant d'exécuter la commande. Ne jamais supposer que `.github/skills/` est le chemin Claude Code ou que `.claude/skills/` est le chemin Copilot. Ces consignes ciblent GitHub Copilot dans VS Code et Claude Code; ne pas présumer qu'elles s'appliquent à claude.ai ou à un autre agent sans vérifier son support des skills et de leurs scripts.

Si la skill est invoquée depuis une autre intégration GitHub que Copilot, les règles de lecture des issues GitHub ne s'appliquent que si l'agent dispose d'un outil GitHub permettant de lire l'issue. Sinon, demander au PO de coller le contenu nécessaire; ne jamais prétendre avoir consulté une issue inaccessible.

## Configuration du PAT (une fois par PO et par profil utilisateur)

- Ne jamais demander, accepter, afficher, journaliser ou placer un PAT dans le chat, un fichier du dépôt, un argument de script ou le JSON temporaire des stories.
- Les scripts détectent automatiquement Windows ou Linux à chaque exécution; ne pas demander au PO de préciser son OS et ne pas mémoriser ce choix.
- Si le PAT est absent ou rejeté par Jira, expliquer au PO : « Créez un PAT personnel dans Jira. Quand vous l'avez, dites-moi que vous êtes prêt; ne le collez pas dans le chat. » Attendre cette réponse avant de lancer la configuration locale.
- Sous Windows, lancer le script avec l'outil PowerShell. Il ouvre une fenêtre locale avec saisie masquée (ou utilise `-TerminalPrompt` si la fenêtre n'est pas disponible) et chiffre le PAT avec DPAPI dans le profil Windows courant.

  ```powershell
  & (Join-Path '<skill-dir>' 'scripts\configure-jira-pat.ps1')
  ```

  Si la fenêtre ne peut pas s'ouvrir, utiliser la saisie masquée du terminal :

  ```powershell
  & (Join-Path '<skill-dir>' 'scripts\configure-jira-pat.ps1') -TerminalPrompt
  ```

- Sous Linux, PowerShell 7 (`pwsh`), `secret-tool` (`libsecret-tools`) et un trousseau Secret Service accessible sont requis. Le script utilise la saisie masquée du terminal et stocke le PAT dans ce trousseau; il ne l'écrit pas dans un fichier. Lancer :

  ```sh
  pwsh -File '<skill-dir>/scripts/configure-jira-pat.ps1'
  ```

- Si `secret-tool` ou le trousseau Linux est indisponible, s'arrêter et expliquer le prérequis; ne pas installer de paquet automatiquement et ne jamais utiliser de fichier en clair comme solution de repli.
- La configuration valide le PAT avec `/rest/api/2/myself` avant de le stocker. Un PAT invalide n'est pas enregistré; un éventuel PAT déjà stocké n'est pas supprimé. Chaque PO configure son propre PAT; ne pas partager le PAT d'un autre utilisateur.
- Le PAT hérite des droits Jira du compte du PO; ce compte doit pouvoir parcourir le projet `ANT` et y créer des issues. La skill ne contourne pas les permissions du projet.
- Si le PAT ne peut pas être configuré, s'arrêter et expliquer le blocage; ne pas basculer vers le navigateur.

## Procédure rapide

1. Identifier la ou les propositions retenues dans la conversation courante ou dans le contenu collé par le PO. Ne pas traiter les idées, options ou résultats exploratoires comme des tickets approuvés. Si aucune proposition prête à créer n'est identifiable, envoyer le message générique défini dans « Identifier les propositions de tickets » et s'arrêter.
2. Vérifier que les champs fonctionnels des propositions retenues sont assez précis pour une création Jira. Réutiliser les titres, composants, objectifs et critères déjà discutés; ne pas les réécrire au-delà d'une mise en forme fidèle, hormis leur traduction en français lorsque nécessaire. Pour une issue GitHub, appliquer les règles de traitement des incertitudes ci-dessus : préserver les critères vérifiables, marquer les validations explicitement demandées comme `À valider par <rôle>`, et ne s'arrêter que si une décision ouverte change le périmètre central ou empêche de définir le ticket sans supposition.
3. Déterminer l'équipe et le composant Jira exacts à partir du besoin fonctionnel et du contexte disponible, sans demander confirmation lorsque l'attribution est claire. Ne traiter qu'une équipe par exécution. Si les propositions retenues couvrent plusieurs équipes, ne pas en choisir une arbitrairement : indiquer les équipes concernées et demander laquelle traiter maintenant; les autres nécessiteront une exécution distincte. Exclure les scopes contestés, les dépendances interéquipes non résolues et le travail externalisé sans ticket Antares. Ne pas exclure une issue dont le besoin principal est la documentation. Compter les tickets admissibles sans avertissement fondé seulement sur leur nombre.
4. Présenter brièvement les champs extraits de la ou des propositions, puis recueillir en un seul échange les seules informations Jira manquantes : composant si l'attribution reste ambiguë, clé Epic complète ou numéro seul (normalisé en `ANT-<numéro>`), et label Plateforme validé s'il est requis. Demander l'Epic après avoir exposé les autres champs; ne pas chercher ni choisir une Epic.
5. Préparer un seul JSON temporaire local en UTF-8 pour l'équipe sélectionnée, sans secret, avec `issueType`, `summary`, `component`, `objective`, `acceptanceCriteria`, `labels` et `epicKey` éventuels. Déterminer `issueType` automatiquement selon la section « Choisir automatiquement le type Jira »; ne pas poser de question séparée sur ce choix. Exemple :

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

   Écrire ces données comme du **JSON brut**, pas comme un hachage PowerShell `[ordered]@{}` contenant des chaînes entre apostrophes. Les apostrophes typographiques (`’`) présentes dans le français peuvent être interprétées comme des délimiteurs de chaîne par PowerShell et faire échouer l'analyse de toute la commande avant l'appel Jira. Utiliser un here-string PowerShell littéral pour le contenu JSON, puis l'écrire explicitement en UTF-8 sans BOM :

   ```powershell
   $jsonText = @'
   <contenu JSON préparé ci-dessus>
   '@
   [System.IO.File]::WriteAllText($jsonPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
   ```

   Le JSON brut préserve les apostrophes, accents et caractères typographiques sans les interpréter comme du code PowerShell. Le script Jira lit ensuite le fichier avec `ConvertFrom-Json`. Chaque ticket doit contenir un `issueType` exactement égal à `Anomalie`, `User Story` ou `Technical Stories`. `epicKey` peut être omis si chaque ticket fournit la sienne. Pour Plateforme, renseigner les labels validés. Garder ce même fichier jusqu'à la fin du flux.
6. Exécuter le précheck **une seule fois** avant la prévisualisation; c'est le premier appel Jira du parcours normal et il vérifie aussi le PAT. Utiliser la commande correspondant au shell disponible :

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <json-temporaire> -ValidateOnly
   ```

   Sous Linux :

   ```sh
   pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <json-temporaire> -ValidateOnly
   ```

   Ce précheck vérifie l'authentification, l'accès aux métadonnées de création pour le projet `ANT`, chaque type sélectionné et ses champs requis, les composants et les Epics. Il ne crée rien. Il ne fait pas de lecture séparée du projet : la clé `ANT` est fixe et les métadonnées de création confirment l'accès nécessaire. Si PowerShell signale une erreur de syntaxe ou si l'écriture du JSON échoue, le script Jira n'a pas été exécuté : corriger uniquement la génération du fichier, puis lancer le précheck. Ne jamais présenter ce cas comme une erreur Jira ni annoncer un précheck réussi. Si le PAT est absent, expliquer au PO : « Créez un PAT personnel dans Jira. Quand vous l'avez, dites-moi que vous êtes prêt; ne le collez pas dans le chat. » Après sa réponse, lancer la configuration locale du PAT selon l'OS; la configuration valide déjà `/rest/api/2/myself`, puis relancer le précheck du même JSON une seule fois. En cas de HTTP 401, demander un nouveau PAT de la même façon, le configurer et retenter le précheck une fois. Ne jamais demander le secret dans la conversation. Pour toute autre erreur d'authentification ou de service, s'arrêter et la rapporter. Si une valeur ou un champ est invalide, corriger seulement le problème identifié puis relancer le précheck; ne pas explorer d'autres routes ni remplacer silencieusement un champ.
7. Présenter un aperçu adapté à la taille du lot : pour un ticket, un aperçu concis de ses champs; pour plusieurs, la liste complète des résumés, types et composants avec les descriptions associées. Toujours inclure le nombre, l'équipe, les labels, l'Epic et le reporter attendu (compte associé au PAT). Afficher le type choisi pour chaque ticket, sans demander de confirmation séparée sur ce type. Signaler toute ambiguïté restante; si elle change le contenu fonctionnel, s'arrêter pour faire cadrer la proposition. Demander une seule confirmation explicite pour toute l'exécution avant toute écriture; toute modification du lot après l'aperçu exige une nouvelle confirmation.
8. Après confirmation, exécuter **une seule fois** le script sans `-ValidateOnly`, avec le même JSON. Sous Windows, utiliser la commande PowerShell; sous Linux, `pwsh -File` avec le chemin à séparateurs `/`. Le script refait ses garde-fous juste avant le premier POST, crée les tickets un par un puis relit chacun pour vérifier le projet, le type, le résumé, la description, le composant, les labels, l'Epic et le reporter. Ne pas relancer le précheck après la confirmation.

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <json-temporaire>
   ```

   ```sh
   pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <json-temporaire>
   ```
9. Supprimer le JSON temporaire dans un bloc `finally`, que l'exécution réussisse ou échoue. Ne jamais supprimer ni modifier le fichier PAT.
10. Rapporter les clés vérifiées et les champs confirmés. En cas d'échec partiel, indiquer les tickets confirmés et ceux dont le résultat est incertain. Si le résultat d'un POST est incertain, rechercher uniquement le résumé concerné par une lecture Jira avant toute décision; ne jamais réessayer automatiquement. Le script expose le statut HTTP et le détail Jira pour faciliter le diagnostic.

La confirmation unique de l'aperçu autorise la création de tout le lot; ne pas redemander une autorisation pour chaque ticket ou appel API. Ne pas rechercher systématiquement des doublons ni lier des tickets. Si le PO signale un doublon potentiel, vérifier ce cas avant l'écriture.

## Correction ciblée d'un texte déjà créé

Si le PO demande explicitement de corriger un titre ou une description mal encodé, utiliser `-RepairExisting` avec un JSON contenant pour chaque ticket `issueKey`, `issueType`, `summary`, `component`, `objective`, `acceptanceCriteria`, `labels` et l'Epic. Le mode exige que le ticket appartienne au projet `ANT`, corresponde au type indiqué, à l'Epic, au composant et au reporter du PAT, et contienne un marqueur de mojibake avant toute modification. Pour les anciens fichiers de réparation sans `issueType`, le script conserve la compatibilité en attendant `User Story`; pour tout nouveau fichier, indiquer explicitement le type attendu. Il met à jour uniquement `summary` et `description`, puis relit et vérifie ces deux champs. Ne pas utiliser ce mode pour modifier une Epic ou d'autres champs.

```powershell
& (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <json-temporaire> -RepairExisting
```

Sous Linux, remplacer l'appel par :

```sh
pwsh -File '<skill-dir>/scripts/create-jira-stories.ps1' -InputPath <json-temporaire> -RepairExisting
```

## Mettre à jour un ticket existant

Utiliser ce mode quand le PO demande de réécrire le contenu d'un ticket Antares déjà créé (surtout sa description, parfois son titre ou ses labels). Ce mode est distinct de `-RepairExisting`, qui ne corrige qu'un mojibake. Le script met à jour uniquement les champs réellement modifiés : `summary` (optionnel), `description` et `labels`. Il fonctionne sur un ticket créé par n'importe quel compte et sur n'importe quel type de ticket (`Anomalie`, `User Story`, `Technical Stories`); le type existant est conservé. Il ne change jamais l'Epic, le composant ou le type; ces éléments servent uniquement de garde-fous de vérification. L'Epic peut être vide en mise à jour (le garde-fou Epic n'est alors pas appliqué).

**Source de la spec**, dans l'un de ces deux cas :
1. Texte fourni dans la conversation courante ou collé par le PO.
2. Page Confluence (certains PO rédigent leurs specs dans `https://gopro-collaboratif.rte-france.com/`). Lire la page avec le script ci-dessous, qui réutilise le PAT Jira : le compte Jira est autorisé sur Confluence. Le script refuse toute URL d'un autre hôte afin de ne jamais envoyer le PAT ailleurs. Il n'affiche pas le contenu de la page : lire ensuite le fichier de sortie pour en extraire la description.

```powershell
& (Join-Path '<skill-dir>' 'scripts\read-confluence-page.ps1') -Url '<url-confluence>' -OutputPath <fichier-temporaire-txt>
```

Sous Linux : `pwsh -File '<skill-dir>/scripts/read-confluence-page.ps1' -Url '<url>' -OutputPath <fichier>`.

Formats d'URL acceptés : `?pageId=<id>`, `/pages/<id>/...`, `/display/<ESPACE>/<Titre>`. Supprimer le fichier temporaire une fois le contenu utilisé.

**Procédure :**
1. Obtenir la spec (texte ou page Confluence). Reformuler la description selon la section « Description des tickets » sans inventer de contenu; signaler les points ambigus comme pour une création.
2. Préparer un JSON temporaire UTF-8 sans BOM, en JSON brut, avec une seule entrée par ticket :

   ```json
   {
     "epicKey": "ANT-1234",
     "stories": [
       {
         "issueKey": "ANT-6078",
         "issueType": "User Story",
         "summary": "Titre mis à jour (optionnel)",
         "component": "Simulateur",
         "objective": "Objectif mis à jour.",
         "acceptanceCriteria": ["Critère observable."],
         "labels": []
       }
     ]
   }
   ```

   `issueKey`, `issueType`, `component` et `objective` sont obligatoires; `epicKey` est optionnel (seul garde-fou appliqué s'il est fourni), et `acceptanceCriteria` doit contenir au moins un critère; `summary` et `labels` sont optionnels et ne sont modifiés que s'ils sont fournis. Lire le ticket actuel avant de présenter le changement.
3. Exécuter le précheck en lecture seule, qui affiche le résumé actuel et proposé, les labels et la description, sans rien écrire :

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <json-temporaire> -UpdateExisting -ValidateOnly
   ```

4. Présenter au PO l'avant/après (au minimum la description, et le titre s'il change), puis demander une seule confirmation explicite avant toute écriture.
5. Après confirmation, exécuter une seule fois sans `-ValidateOnly` :

   ```powershell
   & (Join-Path '<skill-dir>' 'scripts\create-jira-stories.ps1') -InputPath <json-temporaire> -UpdateExisting
   ```

   Le script relit le ticket après la mise à jour et affiche `UPDATED AND VERIFIED` ou `UNCHANGED`.
6. Supprimer le JSON temporaire et le fichier Confluence temporaire dans un bloc `finally`. Rapporter la clé et les champs modifiés.

Ne jamais lancer le mode de mise à jour sur un ticket sans confirmation explicite du PO pour ce ticket précis.

## Description des tickets

Utiliser exactement ces deux sections dans la description :

```markdown
**Objectif / pourquoi**
<résultat fonctionnel ou technique et raison du ticket>

**Critères d'acceptation**
- <critère observable et testable>
```

Les critères doivent rester fidèles au découpage approuvé. Ne rien inventer pour combler une inconnue. Si l'issue demande explicitement une vérification ou une validation et en nomme le responsable, conserver ce point sous la forme `À valider par <nom/rôle>` et le signaler dans l'aperçu. Pour toute autre incertitude, demander au PO s'il souhaite la conserver ainsi ou faire préciser le besoin avant le précheck.

Pour une `Anomalie`, reprendre dans l'objectif ou les critères le comportement observé et le comportement attendu lorsqu'ils sont fournis dans la proposition; ne pas en inventer si l'un des deux manque.

## Limites

- Ne créer aucun ticket avant la confirmation explicite de l'aperçu.
- Ne pas choisir d'Epic, d'équipe, de composant ou de label à la place du PO lorsque le contexte ne permet pas de les établir; déduire l'équipe et le composant si le besoin les rend clairs et normaliser un numéro d'Epic seul en clé `ANT-<numéro>`, puis vérifier cette clé au précheck.
- Ne pas ouvrir le navigateur intégré. Hors des modes de correction (`-RepairExisting`) et de mise à jour (`-UpdateExisting`), ne modifier aucune Epic ni aucun champ existant. Le mode de mise à jour ne modifie jamais l'Epic, le composant ou le type; changer ces éléments reste hors périmètre.
- Si Jira refuse un champ, une permission est manquante ou la vérification d'une issue créée échoue, s'arrêter, préserver les tickets déjà créés et rapporter précisément l'état.
- Si le précheck reçoit HTTP 404 `Issue Does Not Exist` en lisant l'Epic, ne rien créer et ne pas deviner ni rechercher une autre Epic. Expliquer que la clé est introuvable ou inaccessible avec le compte PAT, puis demander au PO une clé d'Epic valide et visible pour ce compte avant de relancer le précheck.
