---
name: audit-legacy
disable-model-invocation: true
description: Audite un projet existant qu'on découvre, sans documentation fiable, au moindre coût en tokens et au plus vite. Cartographie shell, sous-agents lancés en parallèle, vérification indépendante, arbitrage, puis seulement écriture des documents. À utiliser en arrivant sur un legacy, avant de remplir un OWASP, des ADR ou une doc d'architecture, ou quand un audit doit produire des constats vérifiables plutôt que des impressions.
---

# Auditer un projet qu'on découvre

Recopier cette checklist et la cocher au fil de l'audit :

```text
- [ ] Session dédiée ouverte, aucun autre sujet en cours
- [ ] 1. Cartographie shell, liste des fichiers par axe, périmètre exclu
- [ ] 2. Tous les axes lancés d'un coup, par le workflow du skill
- [ ] 3. Constats vérifiés, négatifs et déductions en priorité
- [ ] 4. Arbitrage : reclassements, corrélations, cas séparés
- [ ] 5. Documents écrits avec chemins et statut vérifié ou supposé
- [ ] 6. Note locale consignée
```

## Répartition du travail

| Travail | Qui le fait |
|---|---|
| Compter, lister, historique git | commandes shell |
| Relever ce qui est stocké, affiché, journalisé, envoyé, protégé | sous-agent `sonnet` |
| Suivre un enchaînement de conditions ou une machine à états | sous-agent `opus` |
| Relevé mécanique sur une liste de fichiers fournie, sans interprétation | sous-agent `haiku` (facultatif) |
| Vérifier, arbitrer, écrire | session principale, qui ne lit pas de fichiers entiers |

Ce que la session principale lit est renvoyé à chaque requête jusqu'à la fin ;
le contexte d'un sous-agent est jeté quand il rend sa conclusion.

## Choisir le modèle d'un sous-agent

Juger au coût de la tâche, pas au prix du token : un modèle qui tâtonne fait plus
de tours, et chaque tour renvoie son contexte.

Le partage ne se fait pas entre sujets sensibles et sujets ordinaires, mais entre
**relever et raisonner** :

- **`sonnet`** pour un axe d'inventaire : quelles données sont stockées,
  affichées, journalisées, envoyées, quels fichiers protègent quoi. Un constat y
  tient dans une ligne ou deux du même fichier.
- **`opus`** pour un axe dont un risque naît d'un enchaînement : parcours de
  paiement, contrôle d'accès, cycle de session, machine à états. Un constat y
  demande de suivre une condition sur plusieurs branches ou de relier deux
  lignes éloignées.
- **`haiku`** uniquement pour relever des occurrences (routes déclarées, appels de
  logger et leurs champs, variables d'environnement lues) dans des fichiers
  fournis. Jamais pour classer ni résumer.

Des règles globales de l'utilisateur peuvent imposer un modèle pour la sécurité
ou l'architecture. Elles l'emportent sur ce tableau : appliquer, et l'annoncer en
une ligne au lancement, en disant ce que ça change pour le coût.

Mesure du 18/09/2026, 3 axes rejoués en `sonnet` sur le même code qu'un audit
`opus`, corrigé constitué des constats vérifiés de cet audit : 13 constats sur 16
retrouvés au bon fichier et à la bonne ligne, 2 trouvailles réelles en plus, à
volume de tokens équivalent. Les 3 ratés étaient tous des enchaînements de
conditions, tous dans l'axe paiement.

## Étape 1 : cartographie

```bash
# Volume par zone
git ls-files | awk -F/ '{print $1"/"$2}' | sort | uniq -c | sort -rn | head -30

# Fichiers qui bougent le plus
git log --since=12.months --name-only --pretty=format: \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -20

# Manifestes de dépendances et CI présents, quel que soit le langage
git ls-files | grep -E '(^|/)(package\.json|pom\.xml|build\.gradle|composer\.json|requirements\.txt|pyproject\.toml|Gemfile|go\.mod|Cargo\.toml)$'
ls .github/workflows/ .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

Sans dépôt git ni historique : `find` remplace `git ls-files`, et l'activité des
fichiers est inconnue. Le signaler dans les documents plutôt que la deviner.

Sans manifeste, les bibliothèques tierces sont souvent recopiées dans le dépôt.
Les repérer, puis lire leur version dans l'en-tête de chaque fichier
(`head -5`) :

```bash
git ls-files | grep -iE '(^|/)(vendor|ext|external|third[_-]?party|libs?)/' \
  | awk -F/ 'NF>2 {print $1"/"$2"/"$3}' | sort -u
```

Les versions relevées sont **vérifiées** ; leurs vulnérabilités connues restent
**supposées** tant qu'elles n'ont pas été confrontées à une base de CVE.

Relever l'écart entre ce que la doc annonce et ce qui existe : c'est souvent la
première trouvaille.

**Point d'arrêt.** Présenter les chiffres (volume, état de la doc, zones
actives) avant de lancer un agent. Si le projet est petit, bien documenté, ou si
la question ne porte que sur un module, le dire et proposer une lecture directe
à la place des sous-agents. Attendre la décision de l'utilisateur.

Produire la liste des fichiers de chaque axe (`git ls-files` filtré par chemin),
à donner aux sous-agents.

Noter aussi ce qui n'entre dans aucun axe, avec le nombre de fichiers et leur
nature (gabarits, langues, affichage pur). Le document le déclarera hors audit :
sans cette mention, le lecteur croit que tout a été lu.

Repérer les fichiers que plusieurs axes réclament (classes utilitaires, couche
d'accès, envoi de courriel, fonctions partagées) et confier chacun à un seul
axe. Les autres consignes le nommeront comme relevant d'un autre axe. Sans ça,
le même fichier est payé deux ou trois fois, et deux agents rendent des
conclusions contradictoires sur les mêmes lignes.

Vérifier chaque chiffre du point d'arrêt par une seconde commande avant de le
présenter. Un motif trop strict fausse un décompte sans jamais échouer :
`^use` ne voit pas les imports indentés.

Si le code n'est pas rangé par domaine, construire la liste par mots-clés, puis
retirer les faux positifs avant de la transmettre (`author` répond à `auth`) :

```bash
git grep -l -i -E 'auth|token|session|password' -- \
  ':(exclude,glob)**/*.lock' ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*'
```

Rattacher l'infrastructure aux axes qu'elle touche : reverse proxy, fichiers
Docker et configuration d'environnement entrent dans l'axe authentification et
autorisation. Pour l'environnement, seulement le gabarit versionné
(`.env.example`) et le code qui lit les variables : jamais un `.env` réel ni un
fichier de credentials, qui ne figurent dans aucune liste transmise. Une faille
se loge souvent dans ce qui entoure le code, et la consigne « ne cherche pas
ailleurs » la rendrait invisible.

## Étape 2 : sous-agents en parallèle

Lancer **tous les axes d'un coup**, y compris ceux qui demandent du
raisonnement. Axes usuels : authentification et autorisation, accès aux données,
conformité à l'architecture annoncée, données sensibles et logs, build et
déploiement, tests. Les axes ne se chevauchent pas : un fichier lu par deux
agents est payé deux fois.

Utiliser l'agent `audit-lecture`, pas un agent d'exploration : celui-ci lit des
extraits pour localiser, il n'audite pas. Le modèle se choisit par axe, selon le
tableau ci-dessus.

`audit-lecture` n'a que `Read`, `Grep`, `Glob` et `Write`, et sa consigne borne
l'écriture à son seul fichier de rapport. Un agent qui ouvre un shell finit par
attendre une permission, et un agent d'arrière-plan qui attend ne le dit pas : il
paraît seulement très lent.

### Lancement par le workflow

Lancer `axes.workflow.js`, rangé à côté de ce fichier, avec l'outil Workflow :
`scriptPath` reçoit le chemin complet du fichier, `args` la cartographie de
l'étape 1.

```json
{ "axes": [ { "nom": "auth", "modele": "opus", "consigne": "…", "rapport": "…" } ] }
```

- `consigne` : le gabarit ci-dessous, rempli pour l'axe. Le workflow n'en porte
  pas d'autre : le gabarit ne vit qu'ici.
- `modele` : `sonnet`, `opus` ou `haiku`, selon le tableau. Jamais omis : sans
  lui, l'agent prendrait le modèle de la session. Le workflow refuse un axe sans
  modèle.
- `rapport` : un fichier du dossier temporaire de la session (scratchpad).

Le workflow rend, pour chaque axe, le décompte, les 10 constats les plus graves,
ce qui n'est pas tranché et les affirmations qui ferment une piste, dans un
format imposé par schéma : un agent qui s'en écarte doit recommencer. Seul ce
rendu revient dans la session principale. Un axe sans rendu est listé dans
`manquants`, à relancer seul.

À défaut (outil Workflow indisponible, agent `audit-lecture` non chargé), lancer
tous les axes dans le même message avec l'outil Agent, même consigne, même
modèle.

Un axe trop gros pour être lu sans compaction se découpe par module, un agent
par module : un agent qui compacte perd ses propres constats.

Gabarit de consigne, en deux variantes. **Premier passage** sur un projet sans
règles écrites : des questions, pour décrire avant de juger. **Second passage**,
ou projet qui a des règles : des violations.

```text
[contexte du projet]

Fichiers à lire : [liste issue de la cartographie]. Ne cherche pas ailleurs,
sauf si un de ces fichiers y renvoie explicitement.

Fichiers partagés relevant d'un autre axe : [liste]. Tu peux les lire pour
comprendre, tu ne rends aucun constat à leur sujet.

Variante questions : réponds à [liste numérotée, par exemple : où est vérifiée
l'identité, quelles routes en sont exemptées, où sont écrites les données].
Variante violations : trouve les VIOLATIONS réelles de [règles numérotées,
énoncées précisément]. Si une règle est respectée partout, dis-le.

Pour CHAQUE constat : chemin exact, numéro de ligne, ligne citée.
Distingue ce que tu as CONSTATÉ de ce que tu DÉDUIS.
Ne propose aucune correction.
Ne recopie jamais la valeur d'un secret (clé, mot de passe, token) : indique
seulement le fichier et la ligne.
N'exécute aucun test, aucune requête réseau, aucune commande qui modifie quoi
que ce soit. N'écris qu'un seul fichier, celui de ton rapport. Pour chaque
constat DÉDUIT, décris en une ligne le test qui le confirmerait ou
l'infirmerait, en préférant un test automatisé dans le code.

Écris le tableau complet de tes constats dans [chemin de rapport], une ligne
par constat, colonnes :
| # | Fichier:ligne | Constat | Constaté ou déduit | Test proposé (si déduit) |

Réponds ici, et rien d'autre :
- le décompte chiffré (constats, dont constatés, dont déduits)
- tes 10 constats les plus graves, au même format de tableau
- ce que tu n'as pas pu trancher, en une ligne chacun
- les affirmations qui ferment une piste (absence, constat rassurant), avec
  leur fichier:ligne
```

Le tableau entier versé dans la réponse est le premier poste de la session
principale : elle le repaie à chaque requête jusqu'à la fin. Le fichier reste
consultable par `grep` quand une vérification le demande. Ranger ces fichiers
dans le dossier temporaire de la session : hors du dépôt audité, ils ne salissent
pas son `git status`, et l'agent doit pouvoir y écrire sans demande de
permission, qu'il attendrait sans le dire (à confirmer au premier lancement
réel). Ce dossier disparaît avec la session : ce qui doit durer
passe dans la note de l'étape 6.

Les agents proposent les tests, la session principale choisit lesquels mener et
où (étape 3).

La liste de fichiers borne le nombre de tours ; le format imposé borne la sortie.

Pendant que les agents tournent, la session principale ne lit rien. Ensuite, elle
ne lit jamais de fichier entier : seulement quelques lignes ciblées (`grep -n`,
plage de lignes) pour vérifier et arbitrer.

## Étape 3 : vérifier

Ne reprendre aucune conclusion d'agent sans la recouper, par `grep` ciblé :

- les affirmations d'**absence** (« aucune fuite », « zéro occurrence »)
- les constats **rassurants** : « recalculé côté serveur », « figé en dur »,
  « déjà assaini ». Ils ferment une piste aussi sûrement qu'une affirmation
  d'absence, et un agent qui a lu les bonnes lignes peut en tirer l'inverse de
  ce qu'elles disent
- les constats les plus graves, un par un
- les **déductions** : une déduction de sécurité se teste avant d'être écrite
  comme un fait

Où tester, par ordre de préférence :

1. Un test automatisé dans le code (unitaire ou d'intégration), sans réseau
2. Une instance locale, avec des données fictives
3. Un environnement de recette, seulement avec l'accord explicite de son
   responsable : il contient souvent une copie de données réelles, et un test
   d'intrusion peut bloquer des comptes ou déclencher des alertes

Jamais la production. Si aucun test n'est possible, la déduction reste marquée
**supposé**, avec le test à mener écrit à côté.

Un test qui recopie une expression hors de son fichier vérifie le **mécanisme**,
pas que la ligne est atteignable avec une entrée contrôlée. L'atteignabilité
s'établit en lisant le code autour : d'où vient la valeur, quel filtre la
précède. Tant qu'elle ne l'est pas, écrire « mécanisme vérifié, exploitation
supposée ».

### Passage adversarial

À lancer une fois les constats repris rassemblés, avant l'arbitrage, et jamais
sur les rendus bruts du workflow : il attaque ce que la vérification a retenu.
Un agent qui ne refait pas l'audit : il reçoit les constats et la liste de
fichiers de l'axe, et cherche par où chaque affirmation qui ferme une piste est
fausse. Sa matière première : les affirmations fermantes rendues par chaque axe,
recoupées à l'étape 3. Un agent par axe, tous dans le même message, avec l'outil
Agent : ils sont trop peu nombreux pour justifier un workflow. Produire une
conclusion et l'attaquer ne mobilisent pas la même lecture : celui qui vient
d'écrire « recalculé côté serveur » relit pour confirmer, celui à qui on demande
le contre-exemple descend la condition branche par branche.

Il coûte une fraction d'un axe : il n'ouvre que les fichiers nécessaires à
quelques affirmations, pas tout l'axe. Modèle `opus`, sans hésiter : c'est le
travail de raisonnement par excellence, sur une petite surface, et c'est la
classe d'erreur où un modèle plus léger échoue.

```text
[contexte du projet]

Voici des affirmations tirées d'un audit de [axe], chacune avec sa preuve :
[liste numérotée : affirmation, fichier:ligne]

Fichiers à lire : [liste de l'axe].

Pour CHAQUE affirmation, cherche un chemin d'entrée ou une branche de condition
où elle est FAUSSE. Descends chaque condition branche par branche, y compris
celles qui paraissent hors sujet.
Tu ne rends aucun constat nouveau : seulement des contradictions à ces
affirmations.
Si tu ne trouves pas de contre-exemple, écris « tenu » et la branche que tu as
suivie pour t'en assurer.
Ne propose aucune correction. N'exécute aucun test ni requête réseau.

Rendu, rien d'autre :
| # | Affirmation | Tenue ou contredite | Fichier:ligne du contre-exemple | Chemin d'entrée |
```

Ce qu'il rend se vérifie comme le reste : un agent à qui on demande de contredire
trouve des contradictions là où il n'y en a pas.

### Second passage complet

Rarement justifié. Le rendement d'un audit supplémentaire s'effondre vite, et le
budget passe mieux dans les tests à mener : une déduction transformée en fait
vaut plus qu'un constat de plus.

Le justifient : de l'argent qui circule, un contrôle d'accès dont dépend un accès
client, une remise contractuelle à un tiers. Alors, un second passage sur ces
seuls axes, jamais sur tous.

Deux règles s'il a lieu :

- **Varier le modèle ou la formulation.** Deux exécutions identiques partagent
  leurs angles morts : la même question sur les mêmes fichiers produit la même
  lecture. Reprendre les mêmes axes en variante « violations » plutôt qu'en
  variante « questions » change ce que l'agent cherche.
- **Pas de vote majoritaire.** Un constat trouvé par un seul passage est souvent
  le bon, parce qu'il est le plus difficile. Les désaccords se tranchent contre
  le code, en relisant les lignes citées, jamais au décompte.

## Étape 4 : arbitrer

Corriger trois défauts des rapports d'agents :

1. **Violation ou décision de conception ?** Un motif délibéré est souvent
   rapporté comme une faute. Reclasser.
2. **Corrélations.** Deux mécanismes concurrents, une règle contredite ailleurs :
   visibles seulement en croisant les rapports.
3. **Cas regroupés.** Trois occurrences d'un même symptôme ont souvent trois
   causes. Les séparer avant de conclure.

Une question nouvelle part dans **un** sous-agent `sonnet` dédié, avec ses
fichiers, plutôt que d'être lue en session principale.

## Étape 5 : écrire

- Chaque ligne porte le chemin du fichier qui la justifie
- Chaque ligne est marquée **vérifié** ou **supposé**
- Une ligne fausse est pire qu'une ligne vide : on lui fait confiance
- Jamais de sortie brute d'agent dans un document livré

Plan du document d'audit, dans cet ordre :

1. **Périmètre et méthode** : commit audité, volume, axes, ce qui est hors audit,
   nombre de constats d'agents et part recoupée
2. **Légende** : sens de vérifié et de supposé
3. **Synthèse** : quelques phrases, les chaînes de risques d'abord
4. **Risques classés** : `| # | Gravité | Risque | Preuve | Statut |`, le statut
   portant le test qui trancherait
5. **Corrélations entre axes**
6. **Cas séparés** : symptômes regroupés par les agents, avec leurs causes
   distinctes
7. **Reclassements et faux positifs écartés**, chacun avec sa raison
8. **Architecture réelle** et **dépendances tierces**, si ces axes ont été
   couverts
9. **Tests à mener**, par priorité, avec l'environnement de chacun
10. **Tests exécutés** : outil, version, résultat

## Maîtriser le coût

Le plus gros poste est presque toujours la session principale qui dure, pas les
sous-agents.

- **Session dédiée**, fermée une fois les documents écrits : tout autre sujet
  traité ensuite repaie le contexte de l'audit à chaque échange.
- **Un seul lancement** de tous les axes.
- **Carte fournie, axes disjoints, format imposé.**
- **Mesurer** : pour chaque agent, modèle, appels d'outils, tokens et durée
  (fournis à la fin de chaque tâche) ; pour la session, le bloc Session de
  `/usage` en fin d'audit (une session neuve part de zéro).
  Sans mesure, la répartition des modèles reste une hypothèse.
- **Agents du workflow** : leur détail se lit dans le dossier de transcription du
  lancement (`journal.jsonl`, un fichier `agent-<id>.jsonl` par agent), dont le
  résultat de l'outil Workflow donne le chemin. Le format reste à confirmer au
  premier lancement réel.

## Étape 6 : consigner

Le skill ne retient rien. Enregistrer dans une note locale du projet (mémoire du
projet ou fichier de travail) :

- les axes couverts et le modèle de chacun
- les constats vérifiés, datés
- les déductions encore à tester
- les faux positifs écartés, avec la raison
- les mesures de coût

Un second passage repart de là.
