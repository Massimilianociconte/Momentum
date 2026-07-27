import type { APIRoute } from 'astro';
import { capabilityMatrix, factSheet, softwareFeatureList } from '@/content/site';
import { siteOrigin } from '@/lib/seo';
import { officialStoreUrl } from '@/lib/store';

export const prerender = true;

/**
 * `/llms.txt` — indice sintetico per assistenti generativi (llmstxt.org).
 * Contiene solo fatti verificabili già presenti sul sito, così una risposta
 * generata a partire da questo file resta coerente con le pagine pubbliche.
 */
export const GET: APIRoute = ({ site }) => {
  const origin = siteOrigin(site);
  const appStoreUrl = officialStoreUrl(import.meta.env.PUBLIC_APP_STORE_URL, 'apple');
  const playStoreUrl = officialStoreUrl(import.meta.env.PUBLIC_PLAY_STORE_URL, 'google');

  const body = `# Momentum

> Momentum è un'app per il padel su iOS e Android, con companion nativi per Apple Watch e Wear OS. Segna i punti anche senza connessione, conserva lo storico delle partite e le rilegge con analisi descrittive.

Il punteggio è registrato come sequenza di eventi sul dispositivo (event sourcing): questo rende affidabili undo, pausa e ripresa, e permette di riallineare telefono e smartwatch senza duplicare eventi quando la connessione torna disponibile.

## In sintesi

${factSheet.map((fact) => `- **${fact.term}**: ${fact.definition}`).join('\n')}

## Funzioni principali

${softwareFeatureList.map((feature) => `- ${feature}`).join('\n')}

## Offline e connessione

${capabilityMatrix
  .map(
    (row) =>
      `- ${row.capability}: ${row.offline ? 'disponibile senza connessione' : 'richiede connessione'} (${row.note.toLocaleLowerCase('it')})`,
  )
  .join('\n')}

## Pagine

- [Home](${origin}/): panoramica del prodotto, guida al punteggio, funzioni, offline-first e domande frequenti.
- [Regole del padel](${origin}/regole-padel/): regolamento FIP in vigore dal 1° gennaio 2026, voce per voce, con numero di regola e fonte per ogni risposta.
- [Supporto](${origin}/supporto/): FAQ complete su punteggio, offline, account, smartwatch e privacy, glossario del padel e modulo richieste.
- [Download](${origin}/download/): APK preview firmati per telefono Android e Wear OS, con guida all'installazione, in attesa degli store ufficiali.
- [Blog](${origin}/blog/): guide e approfondimenti su padel, punteggio, smartwatch e allenamento (feed: ${origin}/blog/rss.xml).
- [Elimina account](${origin}/elimina-account/): procedura per eliminare account e dati cloud.
- [Informativa privacy](${origin}/privacy/): dati trattati, basi giuridiche e diritti degli interessati.
- [Termini di servizio](${origin}/termini/): condizioni d'uso, abbonamenti e risoluzione delle controversie.
${appStoreUrl ? `- [App Store](${appStoreUrl}): download ufficiale per iPhone e Apple Watch.\n` : ''}${playStoreUrl ? `- [Google Play](${playStoreUrl}): download ufficiale per Android e Wear OS.\n` : ''}

## Note

- Le statistiche sono descrittive e dichiarano campione e limiti: non sono un ranking federale né una previsione.
- Lo scoring vocale è push-to-talk in italiano; non c'è ascolto ambientale continuo.
- Le funzioni cloud, social, Duo Mode e AI sono condizionali a build, configurazione, piano e rollout; non sono presentate come universalmente disponibili.
- Lo Star Point FIP 2026 è supportato dal motore offline e dai companion aggiornati per Apple Watch e Wear OS; il telefono blocca l’invio a companion che non dichiarano il protocollo compatibile.
- Integrazioni con Garmin, Fitbit, Oura e WHOOP non sono promesse come disponibili al lancio.
- Contenuto completo in formato testo: [llms-full.txt](${origin}/llms-full.txt)

## Dettagli

- [Testo esteso](${origin}/llms-full.txt): tutte le FAQ, il glossario e la guida al punteggio in un unico file.
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
