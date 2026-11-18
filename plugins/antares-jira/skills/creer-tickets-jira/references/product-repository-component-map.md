# Product, repository and Jira component mapping

Use the affected product or behavior to identify the Jira component. The repository hosting an issue or documentation does not automatically determine the owning team.

## Components by team

| Owning team | Exact Jira components |
|---|---|
| Simu, including GEMS and Converter | `Simulateur`, `Xpansion` |
| Plateforme | `AntaresWeb`, `antares-craft` |
| Pegase | `Pegase` |

## Repositories and components

| Affected repository | Exact Jira component |
|---|---|
| `Antares_Simulator` | `Simulateur` |
| `AntaREST` | `AntaresWeb` |
| `antares_craft` | `antares-craft` |
| `antares-datamanager-back` | `Pegase` |
| `antares-datamanager-front` | `Pegase` |
| `antares-xpansion` | `Xpansion` |

`antares-doc` is cross-product documentation and does not by itself determine a Jira component. Infer the component from the product whose behavior is described or the reference repository used for comparison. For example, an `antares-doc` request comparing documentation with `Antares_Simulator` and concerning simulator behavior belongs to `Simulateur`.

If the need genuinely spans multiple products or components, or context is insufficient, ask the PO to clarify before choosing a component.
