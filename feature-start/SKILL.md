---
name: feature-start
description: Démarre une nouvelle feature avec un git worktree isolé selon le workflow Git obligatoire du projet
disable-model-invocation: false
---

Demande à l'utilisateur l'identifiant et le nom de la feature à démarrer.
Exemples d'identifiants : AUTH-01, SYNC-01, MOB-03, WEB-01, DEVOPS-02

Format attendu de la branche : `feature/XXX-00-nom-court`
Exemples : `feature/AUTH-01-jwt-patients`, `feature/MOB-03-questionnaire-offline`

Une fois l'info obtenue, exécute dans l'ordre :

1. `git fetch origin dev` — récupère le dernier état de dev sans changer de branche
2. `git worktree add ../sauverLaFace-[ID] -b feature/[ID]-[nom] origin/dev` — crée un worktree isolé basé sur dev
3. Dans le worktree : `git -C ../sauverLaFace-[ID] push -u origin HEAD` — publie la branche pour déclencher le workflow GitHub Actions

Confirme le worktree créé et publié en indiquant :
- Le chemin du worktree : `../sauverLaFace-[ID]`
- Le push est obligatoire pour déclencher le workflow GitHub Actions qui met `features.md` à `[~]`
- La PR sera créée vers `dev` uniquement quand la feature est **terminée et testée**

## Nettoyage automatique après merge

Dès que la PR ouverte depuis ce worktree est mergée dans `dev` (que ce soit toi qui la merges via `gh pr merge`, ou que l'utilisateur t'informe qu'elle l'a été), supprime le worktree automatiquement, sans attendre que l'utilisateur le demande :

```bash
git worktree remove ../sauverLaFace-[ID]
```

- Si l'erreur est `Filename too long` ou `Permission denied` : `core.longpaths` doit être activé globalement (`git config --global core.longpaths true`) — demande confirmation à l'utilisateur avant de le faire si ce n'est pas déjà configuré, cette commande modifiant la config Git globale
- Si `git worktree remove` échoue encore après ça (dossier verrouillé par un process, ou déjà désenregistré par une tentative précédente) : vérifier `git worktree list`, puis si le dossier existe encore sur le disque, le vider avec un `robocopy <dossier_vide> <dossier_a_supprimer> /mir` (contourne les limites de chemin de `rm`/`git` sur Windows) suivi d'un `rmdir`
- Confirme la suppression à l'utilisateur en une ligne, pas besoin de détailler la méthode utilisée sauf si un contournement a été nécessaire
