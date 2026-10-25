export const meta = {
  name: 'audit-legacy-axes',
  description: 'Audit legacy : un agent audit-lecture par axe, en parallèle, rendu au format imposé',
  whenToUse: 'Étape 2 du skill audit-legacy, avec la cartographie de l\'étape 1 en args',
  phases: [{ title: 'Audit', detail: 'un agent par axe, modèle choisi par axe' }],
}

// args : { axes: [{ nom, modele, consigne, rapport }] }, produit par l'étape 1 du skill.
// La consigne est le gabarit du skill rempli pour l'axe : le workflow n'en porte pas d'autre.

const LIGNE = {
  type: 'object',
  required: ['fichier_ligne', 'constat', 'statut'],
  properties: {
    fichier_ligne: { type: 'string' },
    constat: { type: 'string' },
    statut: { type: 'string', enum: ['constaté', 'déduit'] },
    test_propose: { type: 'string' },
  },
}

const RENDU = {
  type: 'object',
  required: ['decompte', 'top10', 'non_tranche', 'affirmations_fermantes'],
  properties: {
    decompte: {
      type: 'object',
      required: ['total', 'constates', 'deduits'],
      properties: {
        total: { type: 'integer' },
        constates: { type: 'integer' },
        deduits: { type: 'integer' },
      },
    },
    top10: { type: 'array', maxItems: 10, items: LIGNE },
    non_tranche: { type: 'array', items: { type: 'string' } },
    affirmations_fermantes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['affirmation', 'fichier_ligne'],
        properties: {
          affirmation: { type: 'string' },
          fichier_ligne: { type: 'string' },
        },
      },
    },
  },
}

const MODELES = ['sonnet', 'opus', 'haiku']
const axes = (args && args.axes) || []
const invalides = axes.filter(a => !a || !a.nom || !MODELES.includes(a.modele) || !a.consigne || !a.rapport)
if (!axes.length || invalides.length) {
  const noms = invalides.map(a => (a && a.nom) || '?').join(', ')
  throw new Error(`Cartographie incomplète : chaque axe demande nom, modele (${MODELES.join(', ')}), consigne et rapport. En défaut : ${noms || 'aucun axe fourni'}`)
}

phase('Audit')
const rendus = await parallel(axes.map(axe => () =>
  agent(
    `${axe.consigne}\n\nÉcris le tableau complet de tes constats dans ${axe.rapport} et n'écris aucun autre fichier. ` +
    'Rends ensuite le décompte, tes 10 constats les plus graves, ce que tu n\'as pas pu trancher, ' +
    'et les affirmations qui ferment une piste (absence, constat rassurant) avec leur fichier:ligne.',
    { label: axe.nom, phase: 'Audit', model: axe.modele, agentType: 'audit-lecture', schema: RENDU },
  ).then(rendu => ({ axe: axe.nom, modele: axe.modele, rapport: axe.rapport, rendu }))
))

const resultat = axes.map((axe, i) => rendus[i] || { axe: axe.nom, modele: axe.modele, rapport: axe.rapport, rendu: null })
const manquants = resultat.filter(r => !r.rendu).map(r => r.axe)
if (manquants.length) log(`Axes sans rendu, à relancer : ${manquants.join(', ')}`)
return { axes: resultat, manquants }
