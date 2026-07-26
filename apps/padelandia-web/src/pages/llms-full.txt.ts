import type { APIRoute } from 'astro';
import {
  capabilityMatrix,
  coreFeatures,
  factSheet,
  faqs,
  glossary,
  howToSteps,
  productMoments,
  ruleSources,
  rulesReviewedOn,
} from '@/content/site';
import { siteOrigin } from '@/lib/seo';

export const prerender = true;

/** `/llms-full.txt` — contenuto editoriale completo in un unico file testuale. */
export const GET: APIRoute = ({ site }) => {
  const origin = siteOrigin(site);

  const body = `# Padelandia — contenuto completo

Fonte: ${origin}/
Lingua: italiano (it-IT)

Padelandia è un'app per il padel su iOS e Android con companion nativi per Apple Watch e Wear OS. Unisce un segnapunti che funziona offline, uno storico delle partite e analisi descrittive del match.

## Scheda sintetica

${factSheet.map((fact) => `### ${fact.term}\n${fact.definition}`).join('\n\n')}

## Funzioni

${coreFeatures.map((feature) => `### ${feature.title}\n${feature.text}`).join('\n\n')}

## Come funziona, in tre momenti

${productMoments.map((moment) => `### ${moment.number} — ${moment.title}\n${moment.text}`).join('\n\n')}

## Come segnare una partita di padel con Padelandia

${howToSteps.map((step, index) => `${index + 1}. **${step.title}** — ${step.text}`).join('\n')}

## Cosa funziona senza connessione

| Funzione | Senza connessione | Nota |
| --- | --- | --- |
${capabilityMatrix.map((row) => `| ${row.capability} | ${row.offline ? 'Sì' : 'No'} | ${row.note} |`).join('\n')}

## Glossario del padel

${glossary.map((entry) => `### ${entry.term}\n${entry.definition}`).join('\n\n')}

## Fonti sulle regole

Ultima revisione editoriale: ${rulesReviewedOn}.

${ruleSources.map((source) => `- [${source.label}](${source.href})`).join('\n')}

## Domande frequenti

${faqs.map((faq) => `### ${faq.question}\n_${faq.category}_\n\n${faq.answer}`).join('\n\n')}

## Limiti dichiarati

- Le analisi sono descrittive: dichiarano campione e limiti e non costituiscono un ranking federale né una previsione garantita.
- Il riconoscimento automatico dei colpi non è incluso.
- L'assistente generativo sulle regole è una funzione connessa e separata dalle FAQ locali; non è un arbitro ufficiale.
- Le funzioni cloud, social, Duo Mode e AI dipendono da build, configurazione, piano e rollout.
- Lo Star Point FIP 2026 non è ancora dichiarato supportato dalla build attuale.
- La compatibilità smartwatch dipende da sistema operativo, modello e configurazione.
- Integrazioni con Garmin, Fitbit, Oura e WHOOP non sono promesse come disponibili al lancio.
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
