# Informativa sulla privacy di Padelandia

**Ultimo aggiornamento: 21 luglio 2026 · Versione 1.5**

La presente informativa è resa ai sensi degli artt. 13-14 del Regolamento (UE)
2016/679 ("**GDPR**"), del D.lgs. 196/2003 come modificato dal D.lgs. 101/2018
("Codice Privacy") e delle policy di Google Play e Apple App Store, per gli
utenti dell'applicazione **Padelandia** (l'"App").

## 1. Titolare del trattamento

> ⚠️ **[DA COMPLETARE prima della pubblicazione]**
> Titolare: **[Nome e cognome / Ragione sociale]**
> Sede: **[indirizzo completo]** — P.IVA/C.F.: **[se applicabile]**

Contatto privacy: **webnovis.info@gmail.com**

## 2. Principio fondante: local-first

Padelandia è progettata secondo i principi di **privacy by design e by default**
(art. 25 GDPR): l'App funziona al 100% senza account. Partite, punteggi,
statistiche, allenamenti e i dati letti direttamente da HealthKit/Health
Connect **restano sul tuo dispositivo**. Fanno eccezione soltanto le funzioni
cloud opzionali descritte sotto, inclusi gli aggregati salute che un utente
Pro sceglie esplicitamente di importare da un provider cloud abilitato.

## 3. Dati trattati, finalità, basi giuridiche, conservazione

### 3.1 Dati locali per impostazione predefinita

| Dato | Origine | Note |
|---|---|---|
| Partite, punteggi, eventi di gioco, statistiche | Inserimento utente / smartwatch | Database locale protetto dal sandbox OS; entrano nel backup soltanto se un utente Premium attiva tale funzione |
| Analytics sportive derivate (pressione, fasi persistenti, turning point, trend) | Calcolo locale post-partita dalla timeline degli eventi | Indicatori descrittivi con campione e incertezza; nessun dato salute, AI esterna o profilazione pubblicitaria |
| Log allenamenti (incl. sforzo percepito RPE e minuti) | Inserimento utente | Locali; entrano nel backup soltanto se un utente Premium attiva tale funzione |
| **Dati salute e fitness locali** (passi, calorie attive, minuti esercizio, frequenza cardiaca durante la partita, workout della partita) | Apple Salute/HealthKit, Apple Watch, Android Health Connect, Wear OS Health Services, solo con consenso | Vedi sez. 6 — restano locali, mai usati per pubblicità |
| Comandi vocali di punteggio | Microfono + riconoscimento vocale del sistema operativo, attivato solo al tocco | Non registrati né inviati ai server Padelandia; il sistema operativo può elaborarli sul dispositivo o tramite il proprio servizio secondo le impostazioni della piattaforma |
| Preferenze e impostazioni | Inserimento utente | Locali; il backup Premium include soltanto le preferenze trasferibili espressamente indicate, mai token, permessi o identificativi dispositivo |

I dati elencati sono memorizzati localmente e puoi eliminarli disinstallando
l'App. Per i comandi vocali Padelandia riceve il testo restituito dal servizio
di sistema solo per il tempo necessario a eseguire il comando, senza conservare
audio o trascrizione. L'eventuale elaborazione del servizio vocale di
piattaforma segue impostazioni e informativa del relativo provider.

### 3.2 Dati trattati sui nostri server (solo con account, opzionale)

| Dato | Finalità | Base giuridica | Conservazione |
|---|---|---|---|
| Email e credenziali (password in hash) | Creazione e gestione account | Contratto (art. 6.1.b) | Fino a eliminazione account |
| Profilo base: nome, nickname, mano dominante, ruolo, livello e privacy | Continuità essenziale dell'account gratuito | Contratto (art. 6.1.b) | Fino a eliminazione account |
| Bio sportiva, lato preferito, area approssimativa, club, fascia oraria, disponibilità, stile di gioco e statistiche pubbliche | Social e matchmaking — **solo se attivi "Visibile sul social"** | Contratto + azione positiva dell'utente (opt-in) | Fino a disattivazione visibilità o eliminazione account |
| Richieste di contatto, proposte partita, richieste team (incl. messaggi) | Matchmaking tra utenti | Contratto (art. 6.1.b) | Fino a eliminazione account |
| Token APNs o identificativo di registrazione FCM (FID), UUID casuale dell'installazione, piattaforma, versione app, lingua e ultimo utilizzo | Recapito facoltativo di richieste social, inviti, aggiornamenti coach/account e altre notifiche operative abilitate dall'utente | Consenso/azione positiva dell'utente (art. 6.1.a); contratto per le comunicazioni operative richieste (art. 6.1.b) | Identificativo fino a disattivazione notifiche, logout o eliminazione account; audit delle consegne max 30 giorni |
| Token di invito in forma hash, tentativi e audit anti-abuso | Link, QR e codici invito revocabili | Contratto; legittimo interesse alla sicurezza (art. 6.1.f) | Fino a scadenza/revoca; audit tecnico secondo necessità di sicurezza |
| Immagine del team | Visualizzazione locale; sincronizzazione privata solo per piani abilitati | Contratto (art. 6.1.b) | Locale fino a rimozione; cloud fino a rimozione o eliminazione account |
| Card "Wrapped" pubblicate con link pubblico | Condivisione volontaria di riepiloghi partita | Consenso mediante pubblicazione volontaria (art. 6.1.a) | Fino a rimozione o eliminazione account |
| Backup strutturato (piani Plus/Pro/Coach): profilo completo, partner, team, riferimenti alle immagini private, partite, timeline eventi, log training e preferenze trasferibili | Backup e ripristino multi-dispositivo | Contratto (art. 6.1.b) | Fino a eliminazione del backup o dell'account |
| Connessione Google Health Pro: token OAuth cifrati e riepiloghi giornalieri (passi, calorie attive, minuti attivi, frequenza cardiaca media se autorizzata) | Riepilogo fitness e continuità tra dispositivi richiesta dall'utente | Contratto (art. 6.1.b) + consenso OAuth esplicito | Token fino a revoca; aggregati max 30 giorni; tutto eliminato alla disconnessione o cancellazione account |
| Connessione diretta Oura/WHOOP Pro, **solo se il relativo rollout viene approvato e attivato**: token OAuth cifrati e aggregati di sonno, HRV, readiness/recovery, strain, workout e frequenza cardiaca media/riposo effettivamente autorizzati | Insight fitness richiesti dall'utente non disponibili in modo equivalente nell'hub salute | Contratto (art. 6.1.b) + consenso OAuth esplicito e granulare | Token fino a revoca; aggregati e metadati tecnici max 30 giorni; eliminazione alla disconnessione o cancellazione account |
| Domande al Pallino Assistant + contesto partita opzionale + contesto locale sintetico (profilo sportivo, stats partite, log/catalogo allenamento, team/coppie minimizzati se abilitati; mai salute di sistema/email/ID account) | Risposte dell'assistente AI (piani Pro/Coach) | Contratto (art. 6.1.b) | Cache limitata delle risposte; log tecnici max 12 mesi |
| Stato abbonamento (piano attivo, scadenza) | Erogazione funzioni premium | Contratto (art. 6.1.b) | Fino a eliminazione account |
| Dati coach marketplace (profilo coach, pacchetti, transazioni) | Marketplace coach (piano Coach) | Contratto (art. 6.1.b); obblighi fiscali (art. 6.1.c) | Transazioni: 10 anni (obblighi contabili) |

**La posizione geografica precisa non viene mai raccolta**: il social mostra
solo un'area indicativa dichiarata dall'utente e posizioni simboliche sulla
mappa. Non usiamo GPS.

Il backup Premium è trasferito tramite TLS e protetto sul database Supabase
da autenticazione, Row Level Security, limite di dimensione e impronta di
integrità SHA-256. Non è cifrato end-to-end con una chiave posseduta soltanto
dall'utente. Sono sempre esclusi dal backup generale: dati HealthKit/Health
Connect e provider salute cloud, token di autenticazione/OAuth, stato abbonamento,
registro dispositivi e notifiche, permessi e percorsi file locali. Analytics
e statistiche vengono ricalcolati da partite, eventi e log training per evitare
copie incoerenti.

Le analytics avanzate sono calcolate sul dispositivo solo dopo la partita.
Sono indicatori sportivi descrittivi e probabilistici, mostrati con numerosita'
del campione e livello di evidenza; non sono ranking federali, diagnosi,
previsioni garantite o decisioni con effetti sull'utente. Il relativo motore
non riceve dati salute e non effettua chiamate a modelli AI o servizi esterni.

Le notifiche remote sono opzionali e vengono registrate soltanto dopo il
consenso del sistema e l'accesso a un account. Su Android l'inizializzazione
automatica di Firebase Cloud Messaging resta disattivata fino a tale scelta;
su iOS il token APNs viene richiesto solo dopo l'autorizzazione. Padelandia non
abilita Firebase Analytics né l'esportazione BigQuery delle metriche FCM. I
token e gli identificativi di registrazione/installazione servono esclusivamente al recapito
e alla deduplicazione delle notifiche, non a pubblicità, analytics cross-app o
profilazione. Logout, revoca o cancellazione account disattivano la
registrazione; gli esiti tecnici delle consegne sono conservati per massimo 30
giorni per retry, sicurezza e diagnosi degli errori.

### 3.3 Dati trattati da terzi per gli acquisti

Gli acquisti avvengono tramite App Store / Google Play. Riceviamo da
**RevenueCat** (nostro responsabile del trattamento) solo lo stato
dell'abbonamento associato a un identificativo: **mai** i dati della carta di
pagamento, che restano presso Apple/Google.

## 4. Natura del conferimento

Il conferimento dei dati per le funzioni cloud è facoltativo: senza account
l'App resta pienamente utilizzabile in locale. Il mancato conferimento
comporta solo l'impossibilità di usare sync, social, backup, assistant e
marketplace.

## 5. Destinatari e responsabili del trattamento

I dati cloud sono trattati, per conto del Titolare, da:

| Fornitore | Ruolo | Sede / trasferimento |
|---|---|---|
| **Supabase Inc.** | Hosting database, autenticazione, funzioni server | UE (regione del progetto) / USA — EU-U.S. Data Privacy Framework e Clausole Contrattuali Standard |
| **RevenueCat Inc.** | Gestione stato abbonamenti | USA — EU-U.S. Data Privacy Framework |
| **Apple Inc. / Google LLC** | Distribuzione app, pagamenti in-app e recapito notifiche tramite APNs/FCM | Secondo le rispettive informative |
| **Google LLC — Google Health API** | Origine dei soli dati salute autorizzati dall'utente Pro tramite OAuth | Secondo Google Health API Terms e garanzie applicabili al trasferimento |
| **Oura Health Oy / ŌURA** | Origine di aggregati Oura autorizzati tramite OAuth, soltanto dopo approvazione e attivazione dell'integrazione diretta | Secondo Oura API Agreement, DPA e garanzie di trasferimento applicabili da verificare prima del rollout pubblico |
| **WHOOP, Inc.** | Origine di aggregati WHOOP autorizzati tramite OAuth e webhook firmati, soltanto dopo approvazione e attivazione | Secondo WHOOP Developer Agreement, DPA e garanzie di trasferimento applicabili da verificare prima del rollout pubblico |
| **Fornitore LLM configurato lato server** | Elaborazione delle domande al Pallino Assistant (solo piani Pro/Coach) | Vedi sez. 7 — da attivare in produzione solo dopo verifica DPA, SCC/DPF e trasferimenti |

Non vendiamo dati personali, non condividiamo dati con terze parti per finalità
pubblicitarie e non effettuiamo tracciamento pubblicitario cross-app.

## 6. Dati salute e fitness — sezione speciale

Se attivi l'integrazione fitness o registri una partita da smartwatch:

- Le integrazioni native Apple Salute/HealthKit e Android Health Connect
  leggono sul telefono solo i tipi autorizzati e mantengono i dati nel
  dispositivo.
- Su Apple Watch, durante una partita attiva e solo con il tuo consenso,
  Padelandia può avviare una sessione workout tramite HealthKit e salvarla in
  Apple Salute come allenamento generico, insieme alle metriche raccolte dal
  sistema durante la sessione (ad esempio durata, calorie attive e frequenza
  cardiaca se autorizzata).
- Su Wear OS / Galaxy Watch, durante una partita attiva e solo con i permessi
  concessi, Padelandia usa Health Services per gestire la sessione workout e
  mostrare/registrare metriche locali come durata, calorie e frequenza
  cardiaca se disponibile.
- Se attivi "Rilevamento allenamento" su Wear OS, il Watch verifica localmente
  soltanto se Health Services segnala un esercizio attivo e la relativa
  categoria. Questo dato serve a mostrare una notifica facoltativa, non viene
  inviato al cloud e non usa posizione o frequenza cardiaca per decidere il
  prompt. Padelandia non apre automaticamente l'app e non interrompe sessioni
  avviate da altre app.
- Sui Garmin compatibili, quando avvii esplicitamente una partita da Padelandia,
  l'app può creare una registrazione FIT Padel/Tennis tramite il sistema
  Garmin. Il file resta nell'ecosistema del dispositivo/Garmin Connect;
  Padelandia sincronizza sul proprio backend gli eventi di punteggio, non il
  file FIT né le metriche salute Garmin. Una sessione Garmin già attiva non
  viene adottata, modificata o terminata.
- Se un utente Pro collega separatamente **Google Health API**, il backend
  richiede via OAuth soltanto gli scope di lettura necessari e calcola il
  riepilogo del **giorno civile corrente**: passi, calorie attive, minuti
  attivi e frequenza cardiaca media se autorizzata. I token sono cifrati
  server-side con AES-GCM; gli aggregati sono conservati per massimo 30 giorni
  e non entrano nel backup generale.
- Disconnettere Google Health revoca il token quando possibile e cancella
  immediatamente token e aggregati Padelandia. I dati Google non vengono
  inviati al fornitore AI né condivisi per finalità pubblicitarie.
- Le integrazioni dirette Oura e WHOOP restano disattivate finché non sono
  presenti approvazione, credenziali e verifica contrattuale. Se attivate per
  un utente Pro, richiedono soltanto gli scope mostrati nel consenso, salvano
  token cifrati AES-GCM e soli aggregati bounded (mai serie cardiache grezze o
  payload webhook completi). La disconnessione tenta la revoca presso il
  provider e cancella token, metriche, job e riepiloghi derivati di Padelandia.
- Oura e WHOOP non sono sensori live per lo scoring. I dati possono arrivare
  dopo la sincronizzazione dell'app del produttore; Padelandia indica sempre
  provider e origine diretta o indiretta e non somma due copie della stessa
  sessione.
- **Mai** usati per pubblicità, marketing, profilazione, valutazione
  creditizia/assicurativa, né ceduti a data broker (conforme a Google Health
  Connect/Health Apps policy e Apple App Review Guideline 5.1.3).
- I permessi sono separati e revocabili in ogni momento da: iOS →
  Impostazioni → Salute → Accesso ai dati; Apple Watch → impostazioni Salute
  e Privacy; Android → app Health Connect / impostazioni permessi; Wear OS →
  impostazioni permessi dell'app sull'orologio.
- Padelandia **non scrive dati su Health Connect**. Su Apple Watch può invece
  scrivere la sessione workout in Apple Salute se autorizzi HealthKit; sui
  Garmin supportati può chiedere al sistema di salvare la sessione FIT avviata
  esplicitamente dall'utente.

L'uso da parte di Padelandia delle informazioni ricevute da Google Health,
Oura o WHOOP è limitato alle funzioni fitness visibili richieste dall'utente e
alle rispettive condizioni del provider. Nessuno di questi dati entra nel
Pallino Assistant.

## 7. Pallino Assistant (intelligenza artificiale)

Il Pallino Assistant è un **sistema di intelligenza artificiale** (LLM):
te lo segnaliamo qui e nell'App in conformità all'art. 50 del Regolamento (UE)
2024/1689 ("**AI Act**"). La versione Free usa solo FAQ e contenuti statici
locali; il modello AI esterno è disponibile solo per piani Pro/Coach o account
amministrativi autorizzati. Quando fai una domanda al Pallino Assistant:

- vengono inviati al fornitore LLM **solo** il testo della domanda, l'eventuale
  contesto di partita che scegli di allegare, un contesto locale sintetico
  dell'app (es. ruolo, livello, statistiche aggregate e training consigliati)
  e la cronologia della conversazione corrente — **mai** i tuoi dati salute, la
  tua email o l'identità del tuo account;
- puoi segnalare una risposta offensiva, non sicura, errata o problematica
  direttamente dalla chat; la segnalazione include domanda, risposta,
  motivo selezionato e dettagli facoltativi;
- le risposte non costituiscono consigli medici, sanitari o professionali;
- l'app è predisposta per usare DeepSeek tramite Edge Function server-side:
  la chiave API resta sul server e non è presente nell'app. Prima
  dell'attivazione in produzione devono essere verificati contratto/DPA,
  garanzie di trasferimento extra-UE (SCC, Data Privacy Framework o base
  equivalente), tempi di conservazione e opzioni di opt-out dal training, ove
  applicabili. In assenza di tali verifiche, l'assistente AI deve restare
  disattivato o usare un provider con garanzie documentate.

## 8. Sicurezza

Trasmissioni cifrate (TLS 1.2+), cifratura at-rest sul database cloud,
politiche di accesso per riga (Row Level Security) che impediscono a ogni
utente di leggere dati altrui, minimizzazione dei dati raccolti, ambienti di
accesso amministrativo protetti da autenticazione forte.

## 9. I tuoi diritti (artt. 15-22 GDPR)

Hai diritto di accesso, rettifica, cancellazione, limitazione, portabilità e
opposizione, nonché di revocare i consensi in ogni momento.

- **Eliminazione account e dati cloud, in autonomia**: App → Profilo →
  Gestisci account → *Elimina account e dati cloud* (effetto immediato e
  definitivo), oppure segui le istruzioni su:
  `https://<DOMINIO_PUBBLICO_RALLYMATE>/account-deletion`
  ⚠️ [sostituire con l'URL HTTPS pubblico prima della pubblicazione]
- **Rettifica**: modifica il profilo direttamente nell'App (sincronizza al
  salvataggio).
- **Ogni altra richiesta**: **webnovis.info@gmail.com** — rispondiamo entro
  30 giorni.

Hai inoltre diritto di proporre reclamo al **Garante per la protezione dei
dati personali** (www.garanteprivacy.it) o all'autorità del tuo Stato UE.

## 10. Minori

L'App non è destinata a minori di **14 anni** (età del consenso digitale in
Italia, art. 2-quinquies Codice Privacy). Non raccogliamo consapevolmente dati
di minori di 14 anni: se ritieni sia accaduto, contattaci per la rimozione
immediata.

## 11. Processi decisionali automatizzati

Il punteggio di compatibilità del matchmaking è calcolato automaticamente da
regole trasparenti (livello, disponibilità, ruolo, stile, affidabilità) e ha il
solo effetto di ordinare i suggerimenti: nessuna decisione con effetti legali o
similari viene presa in modo automatizzato (art. 22 GDPR).

Anche gli indici di performance sono elaborazioni statistiche locali e
indicative della timeline di gioco. Servono esclusivamente a presentare un
resoconto all'utente e non determinano accesso a servizi, prezzi, premi,
sanzioni o altri effetti giuridici o analogamente significativi.

## 12. Modifiche

Le modifiche sostanziali saranno comunicate nell'App con almeno 15 giorni di
anticipo. La versione vigente è sempre disponibile a questo indirizzo e nella
sezione Privacy dell'App.
