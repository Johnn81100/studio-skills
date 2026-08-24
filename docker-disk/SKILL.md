---
name: docker-disk
description: Récupérer l'espace disque pris par Docker sous Windows/WSL2 — purge des images, conteneurs, volumes et build cache, puis compactage du fichier docker_data.vhdx qui ne rétrécit jamais tout seul. À utiliser quand le disque est plein, quand AppData/Local/Docker pèse des dizaines de Go, ou quand un prune ne libère rien côté Windows.
---

# Récupérer l'espace disque de Docker (Windows / WSL2)

## Le mécanisme à comprendre d'abord

Sous Windows, Docker stocke tout dans **un seul fichier** :
`%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx`

Ce fichier **grossit** quand Docker écrit, et **ne rétrécit jamais** quand Docker
efface. Un `docker system prune` vide l'intérieur du disque virtuel, mais Windows
continue de voir un fichier de la même taille.

D'où deux phases distinctes, et il faut les deux :

1. **Purger** — libère l'espace *à l'intérieur* du .vhdx
2. **Compacter** — rend l'espace *à Windows*

Faire seulement la phase 1 ne change rien à l'espace libre du disque. Ne pas
laisser croire le contraire : l'annoncer avant, sinon la purge passe pour un échec.

## Phase 0 — Diagnostiquer

```bash
docker system df                                    # ce qui est occupé et récupérable
ls -lh "$LOCALAPPDATA/Docker/wsl/disk/docker_data.vhdx"   # taille réelle côté Windows
df -h /                                             # espace libre
```

L'écart entre le total de `docker system df` et la taille du .vhdx est l'espace
mort que seul le compactage récupérera.

Si le démon ne répond pas, démarrer Docker Desktop :
`Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"` puis attendre.

## Phase 1 — Purger

### Vérifier avant de supprimer

Un prune avec `--volumes` détruit des données de façon irréversible. Ne jamais
supposer que les volumes sont vides : le vérifier.

```bash
docker system df -v          # taille par volume
docker ps -a                 # conteneurs, dont ceux qui tournent
docker volume ls
```

Pour un volume PostgreSQL, la taille tranche seule : un cluster vierge pèse
~70 Mo, et une base fraîchement créée sans table ~8 Mo. Au-delà, il y a des
données. Inspecter au besoin :

```bash
docker start <conteneur-postgres>
docker exec <conteneur> sh -c 'du -sh /var/lib/postgresql/data/base/*'
```

Présenter à l'utilisateur ce qui part, ce qui reste et le gain estimé **avant**
d'agir. S'il y a le moindre doute sur un volume, proposer un dump plutôt que
supposer.

### Purger

```bash
docker stop $(docker ps -q)          # rend tout éligible au prune
docker system prune -a --volumes -f
docker volume prune -a -f            # INDISPENSABLE, voir ci-dessous
```

**Le piège des volumes nommés.** Depuis Docker 23, `--volumes` ne supprime que
les volumes **anonymes**. Les volumes **nommés** (`monprojet_postgres_data`)
survivent au `system prune` et exigent `docker volume prune -a`. Sans cette
seconde commande, plusieurs Go restent en place alors que le rapport annonce
une purge complète.

**Le prune est bloqué par le garde-fou d'auto mode**, et c'est normal : c'est
irréversible. Ne pas chercher à contourner — donner la commande à l'utilisateur
pour qu'il la lance lui-même avec le préfixe `!`, sa sortie revient dans la
conversation.

## Phase 2 — Compacter le .vhdx

### Tout arrêter

1. **Quitter Docker Desktop pour de bon** — clic droit sur l'icône dans la barre
   des tâches, *Quit Docker Desktop*. Fermer la fenêtre ne suffit pas : le
   processus continue et verrouille le fichier.
2. `wsl --shutdown`

**Avertir avant** : `wsl --shutdown` arrête **toutes** les distributions, pas
seulement `docker-desktop`. Une session Ubuntu WSL en cours sera coupée.

Vérifier ensuite que la voie est libre :

```bash
wsl -l -v          # toutes les distributions doivent être "Stopped"
```

### Compacter

Le skill embarque un script qui fait tout : `scripts/compact-vhdx.ps1`.

```powershell
& "$env:USERPROFILE\.claude\skills\docker-disk\scripts\compact-vhdx.ps1"
```

Il résout le chemin du .vhdx tout seul (trois emplacements connus selon la
version de Docker Desktop), refuse de démarrer sans élévation, vérifie que Docker
Desktop est quitté, arrête WSL, contrôle qu'aucune distribution ne tourne encore,
compacte, puis affiche le bilan avant/après. Chaque échec sort en code 1 avec la
cause et la correction.

Le passer à l'utilisateur : lui seul peut ouvrir un terminal administrateur.

### Ce que fait le script, si tu dois le refaire à la main


`Optimize-VHD` (module Hyper-V) est absent de la plupart des éditions Windows
Home — vérifier avec `Get-Command Optimize-VHD`, et se rabattre sur diskpart.

diskpart est **interactif** : lancé nu, il ouvre son propre prompt `DISKPART>` et
reste bloqué sans terminal. Écrire un script et l'appeler avec `/s` :

```
select vdisk file="C:\Users\<user>\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

Fins de ligne CRLF, chemin court et facile à taper (ex. `C:\Users\<user>\compact-docker.txt`).

Puis, dans un **PowerShell en administrateur** :

```powershell
diskpart /s C:\Users\<user>\compact-docker.txt
```

**L'élévation est le vrai blocage, pas l'interactivité.** Le `!` de Claude Code
tourne avec les privilèges de la session, jamais en administrateur : cette
commande ne peut pas être lancée à la place de l'utilisateur. Le `/s` règle
l'interactivité et la sortie reste visible (progression en pourcentage).

`attach vdisk readonly` n'est pas décoratif : le disque est monté en lecture
seule, rien ne peut y écrire pendant l'opération. Et `select vdisk file=`
sélectionne **un fichier**, jamais un disque physique — aucun risque de toucher
un vrai volume, contrairement à un `select disk` suivi d'un `clean`.

Si `attach vdisk` répond que le fichier est utilisé : Docker Desktop tourne
encore, ou une distribution WSL s'est relancée. Refaire `wsl --shutdown` juste avant.

## Phase 3 — Vérifier

```bash
ls -lh "$LOCALAPPDATA/Docker/wsl/disk/docker_data.vhdx"
df -h /
```

Un .vhdx purgé puis compacté retombe typiquement à 4-8 Go. Rappeler qu'il
regrossira au fil des builds : c'est le fonctionnement normal, on repart d'une
base propre.

## Ordre de grandeur

Sur une installation de trois ans jamais nettoyée, le build cache est presque
toujours le premier poste — devant les images. Vérifier `docker system df` avant
de supposer que ce sont les images qui pèsent.
