---
name: creer-tickets-jira
description: "Use when asked to create and verify one or more already-framed Antares Jira tickets via the Jira REST API, or to repair explicitly identified mojibake in a ticket created by this workflow."
argument-hint: "Proposition(s) validée(s), équipe cible et clé(s) Epic"
---

# Créer des tickets Jira Antares

Cette skill utilise l'API du Jira Antares pour créer des tickets déjà cadrés, pour une seule équipe par exécution. Elle ne conçoit pas le besoin et ne choisit pas le périmètre à la place du PO.

**Avant toute action**, lire et appliquer la procédure complète dans [workflow-jira.md](references/workflow-jira.md). Elle contient les règles de classification, les prérequis, les commandes, les contrôles et les limites, y compris pour la correction ciblée d'un texte mal encodé. Les chemins `<skill-dir>` dans cette procédure désignent le dossier contenant ce `SKILL.md`.

Consulter [product-repository-component-map.md](references/product-repository-component-map.md) pour identifier l'équipe et le composant Jira. Les scripts nécessaires sont inclus dans `scripts/`; les prérequis et les sources sont décrits dans [sources.md](references/sources.md).

Ne jamais demander de PAT dans le chat. Avant toute création, effectuer le précheck sans écriture, présenter l'aperçu complet et obtenir une confirmation explicite. Rapporter les résultats vérifiés et les éventuels échecs sans relancer automatiquement les écritures.
