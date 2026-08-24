---
name: pat-github
description: Révoquer et recréer le token GitHub fine-grained (PAT) utilisé par le plugin MCP github, avec les 8 permissions validées et le stockage en variable d'environnement. À utiliser quand le token expire (90 jours), quand les outils mcp__plugin_github_github__* renvoient 401/403, ou quand le token a pu fuiter.
---

# Renouvellement du PAT GitHub

## Contexte technique

Le plugin `github@claude-plugins-official` lit son `.mcp.json` :

```json
{ "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/",
  "headers": { "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}" } } }
```

Il n'existe **aucune option OAuth** pour ce plugin (contrairement à Figma). Il
lui faut obligatoirement la variable d'environnement `GITHUB_PERSONAL_ACCESS_TOKEN`.
Ce qu'on choisit, c'est d'où elle vient.

## Étape 1 — Révoquer l'ancien token

Faire révoquer d'abord, nettoyer ensuite : jamais de fenêtre où un token vivant
traîne dans un fichier.

Envoyer l'utilisateur sur https://github.com/settings/tokens, onglet
**Fine-grained tokens**, et supprimer l'ancien.

Si le token était en clair dans un fichier ou a pu être lu par un agent (donc
présent dans un transcript sous `~/.claude/projects/`), insister : le déplacer
ne répare rien, il faut le révoquer.

## Étape 2 — Créer le nouveau

Réglages validés, à reproduire à l'identique :

- **Repository access : Only select repositories** — lister les projets actifs.
  Jamais « All repositories ». C'est l'axe le plus efficace, souvent négligé.
- **Expiration : 90 jours** — jamais « No expiration ».

| Repository permission | Niveau |
|---|---|
| Contents | Read and write |
| Issues | Read and write |
| Pull requests | Read and write |
| Workflows | Read and write *(uniquement si push dans `.github/workflows/`)* |
| Metadata | Read *(coché automatiquement)* |
| Actions | Read |
| Commit statuses | Read |
| Secret scanning alerts | Read |

**Account permissions : aucune.**
**Organization permissions :** `Members: Read` uniquement si dépôts d'orga.

### Ce qui reste décoché, et pourquoi

- **Administration** — seule permission couvrant `DELETE /repos` (destruction),
  le `PATCH` de visibilité (privé -> public en un appel), la suppression des
  protections de branche, et l'ajout de collaborateurs. Ce dernier point est le
  plus grave : c'est un accès qui **survit à la révocation du token**. Elle ne
  débloque que `create_repository` et `delete_repository` — créer un dépôt via
  l'interface web à la place. Note : `list_repository_collaborators` relève de
  Metadata, pas d'Administration.
- **Account permissions** — elles ne sont **pas** limitées par le scoping par
  dépôt. `Watching`/`Starring` en Read exposent les noms de dépôts privés hors
  sélection ; `Email addresses` expose les adresses privées. Aucun outil du
  plugin n'en a besoin (`get_me` fonctionne, champ `email` vide).
- **Dependabot alerts / secrets** — aucun outil du plugin n'y touche. À ne pas
  confondre avec `Secret scanning alerts`, qui sert à `run_secret_scanning`.

## Étape 3 — Stocker le token

**Ne jamais faire taper le token dans la session Claude Code** — ni via `!`, ni
dans un fichier que l'agent lit : il repartirait dans le transcript.

Demander à l'utilisateur de le poser lui-même, hors Claude Code :

- `Win+R` -> `sysdm.cpl` -> *Paramètres système avancés* -> *Variables
  d'environnement* -> *Nouvelle* dans la section utilisateur, ou
- dans un PowerShell séparé :
  `[Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','<token>','User')`

Ne pas le remettre dans `~/.claude/settings.json`. Le gain n'est pas contre un
malware local (les deux sont lisibles sous le compte) mais contre l'exposition
accidentelle : un fichier de config se copie, se partage, se capture en image et
se fait lire par un agent.

Vérifier ensuite que `~/.claude/settings.json` ne contient plus de
`GITHUB_PERSONAL_ACCESS_TOKEN` dans son bloc `env` — en préservant les autres
clés (`NODE_EXTRA_CA_CERTS`). Supprimer tout `settings.json.bak` résiduel.

## Étape 4 — Vérifier

Claude Code hérite de l'environnement **au démarrage** : il faut le redémarrer.

Ensuite, tester avec `mcp__plugin_github_github__get_me`. Un 401 signifie que la
variable n'est pas vue (redémarrage oublié, ou variable posée en « système » au
lieu de « utilisateur »). Un 403 sur un dépôt précis signifie qu'il manque dans
*Only select repositories*, ou qu'une approbation admin d'organisation est en
attente.

## Pièges connus

- **Workflows est séparé de Contents.** Sans elle, tout push touchant un fichier
  sous `.github/workflows/` échoue en 403, avec un message peu explicite.
  `.github/dependabot.yml` n'est **pas** concerné (hors de `workflows/`) :
  Contents suffit.
- **Dépôts d'organisation** : les tokens fine-grained doivent être autorisés par
  l'orga et souvent approuvés par un admin. Si rien ne marche sur un repo d'orga,
  chercher là avant de suspecter les permissions.
- **Le terminal doit être fermé, pas seulement Claude Code.** Une variable
  d'environnement utilisateur nouvellement posée n'est pas propagée aux processus
  déjà lancés — le terminal hôte inclus. Relancer Claude Code depuis le même
  terminal ne suffit pas : fermer la fenêtre et en ouvrir une nouvelle.
- **Modifier sans régénérer** : pour ajuster des permissions ou ajouter un dépôt,
  ouvrir le token existant sur la page des settings et l'éditer en place. Une
  modification peut redéclencher une approbation admin côté orga.

## Étape 5 — Enregistrer l'échéance

Ce skill ne contient que la **procédure**, jamais l'**état** : la date de
renouvellement et la liste des dépôts sélectionnés sont propres à chaque machine
et à chaque personne, et n'ont donc pas leur place ici.

En fin de parcours, enregistrer ou mettre à jour une note locale contenant
uniquement :

- la date de création du token et l'échéance (création + 90 jours)
- la liste des dépôts cochés dans *Only select repositories*

Dans Claude Code, la place naturelle est la mémoire du projet
(`~/.claude/projects/<projet>/memory/github-pat-config.md`, type `reference`,
avec une ligne dans `MEMORY.md`). Ailleurs, n'importe quelle note locale fait
l'affaire.

Si cette note n'existe pas encore — premier passage, nouvelle machine, autre
utilisateur — la créer plutôt que de considérer que c'est une erreur. Le skill
s'amorce ainsi tout seul, sans rien présupposer de l'environnement.
