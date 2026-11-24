# Correspondance produits, dépôts et composants Jira

Utiliser le produit ou le comportement concerné pour identifier le composant Jira. Le dépôt qui héberge une issue ou une documentation ne détermine pas automatiquement l'équipe propriétaire.

## Composants par équipe

| Équipe propriétaire | Composants Jira exacts |
|---|---|
| Simu, dont GEMS et Converter | `Simulateur`, `Xpansion` |
| Plateforme | `AntaresWeb`, `antares-craft` |
| Pegase | `Pegase` |

## Dépôts et composants

| Dépôt concerné | Composant Jira exact |
|---|---|
| `Antares_Simulator` | `Simulateur` |
| `AntaREST` | `AntaresWeb` |
| `antares_craft` | `antares-craft` |
| `antares-datamanager-back` | `Pegase` |
| `antares-datamanager-front` | `Pegase` |
| `antares-xpansion` | `Xpansion` |

`antares-doc` est une documentation transverse et ne détermine pas à lui seul un composant Jira. Déduire le composant du produit dont le comportement est décrit ou du dépôt de référence utilisé pour la comparaison. Par exemple, une demande dans `antares-doc` qui compare la documentation à `Antares_Simulator` et concerne le comportement du simulateur relève de `Simulateur`.

Si le besoin concerne réellement plusieurs produits ou composants, ou si le contexte ne permet pas de trancher, demander une clarification au PO avant de choisir un composant.
