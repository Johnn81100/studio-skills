# studio-skills

Collection de skills pour [Claude Code](https://claude.ai/code).

Un skill est une procédure packagée : seuls son nom et sa description restent en
contexte, et le corps ne se charge qu'au moment où il est invoqué — par l'agent
quand il juge que c'est pertinent, ou par l'utilisateur avec `/<nom>`.

## Skills disponibles

| Skill | À quoi ça sert |
|---|---|
| **`/feature-start`** | Démarre une feature dans un git worktree isolé, selon la convention de branche `feature/XXX-00-nom-court` |
| **`/find-skills`** | Cherche et installe des skills depuis l'écosystème public, quand une capacité manque |
| **`/pat-github`** | Renouvelle le token GitHub fine-grained du plugin MCP `github` : révocation, les 8 permissions retenues, stockage hors fichier de config |
| **`/tailwind-v4-shadcn`** | Mise en place Tailwind CSS v4 + shadcn/ui sur Vite/React : `@theme inline`, variables CSS, dark mode, pièges de la v4 |

## Installation

Copier le dossier du skill voulu dans `~/.claude/skills/` :

```bash
cp -r pat-github ~/.claude/skills/
```

Les skills y sont **globaux** — disponibles depuis n'importe quel projet. Pour
limiter un skill à un seul projet, le placer dans `.claude/skills/` à la racine
de ce projet.

Aucun redémarrage n'est nécessaire : les skills sont détectés à chaud.

## Convention : procédure ici, état ailleurs

Un skill de ce dépôt ne contient **que la procédure**. Jamais l'état : pas de
dates d'échéance, pas de chemins absolus, pas de noms de dépôts, pas de
credentials.

L'état est propre à chaque machine et à chaque personne. Quand un skill en a
besoin, il le **crée** au lieu de le supposer — sa dernière étape enregistre ce
qu'il faut retenir dans une note locale (la mémoire du projet sous
`~/.claude/projects/<projet>/memory/` dans Claude Code, ou n'importe quel fichier
ailleurs).

C'est ce qui rend un skill réutilisable tel quel sur une autre machine ou par
quelqu'un d'autre : rien n'y présuppose l'environnement dans lequel il tourne.
