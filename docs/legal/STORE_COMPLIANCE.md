# Padelandia — Guida operativa compliance store

**Aggiornata al 15 luglio 2026.** Obiettivo: approvazione al primo tentativo su
Google Play e App Store. Le sezioni ⚠️ richiedono un'azione prima della
submission.

---

## 0. Cose da fare PRIMA della submission (bloccanti)

| # | Azione | Stato |
|---|---|---|
| 1 | ⚠️ Completare Titolare/ragione sociale in PRIVACY_POLICY(.EN) e TERMS_OF_SERVICE | da fare |
| 2 | ⚠️ Pubblicare Privacy, Termini e pagina eliminazione su un **URL HTTPS pubblico stabile**. Il dominio condiviso Supabase forza HTML/XHTML a `text/plain`; usare il sito Padelandia oppure un custom domain | da fare |
| 3 | `delete-account` è attiva e il POST autenticato è il percorso in-app; il GET restituisce le istruzioni, ma la pagina web professionale va ospitata come indicato al punto 2 | backend attivo / URL web da fare |
| 4 | Configurare in build gli URL pubblici: `--dart-define=RALLYMATE_PRIVACY_URL=...` e `--dart-define=RALLYMATE_TERMS_URL=...`; il paywall e la schermata Privacy li leggono da `CloudConfig` | da fare |
| 5 | ⚠️ Creare account demo per i reviewer: almeno 1 Pro, consigliati 2 account per social/matchmaking; indicare credenziali nelle Review Notes | da fare |
| 6 | ⚠️ Valutare il fornitore LLM prima della produzione: DeepSeek o altro provider richiedono DPA, garanzie trasferimento dati (SCC/DPF/base equivalente), retention e opt-out training documentati. Se non verificato, tenere Assistant disattivato | decidere |
| 7 | `assistant` e migration sono attive; predisporre una routine interna per controllare le segnalazioni AI in `assistant_reports` | backend attivo / processo da definire |
| 8 | Configurare RevenueCat, prodotti store e offering mensile; verificare acquisto, restore e gestione/disdetta dallo store | da fare |
| 9 | Test su device fisici: HealthKit/Apple Watch workout, Health Connect Android, Wear OS Health Services/Samsung Galaxy Watch con permessi negati/concessi/revocati | da fare |
| 10 | Garmin è compilata su 95 profili e ha un export firmato; completare QA visiva/hardware e review Connect IQ. Fitbit richiede ancora QA hardware e Gallery review | da fare prima dei claim pubblici |
| 11 | ⚠️ Configurare upload key Android tramite le quattro variabili `RALLYMATE_ANDROID_*`, generare AAB firmato e iscriversi a Play App Signing | da fare |
| 12 | ⚠️ Configurare RevenueCat e il relativo webhook secret prima di deployare `revenuecat-webhook` | da fare |
| 13 | ⚠️ Configurare dominio e file `apple-app-site-association` / `assetlinks.json` prima di pubblicizzare Universal Links e Android App Links; oggi è registrato solo lo schema `rallymate://` | da fare se gli inviti web entrano nel listing |
| 14 | Accettare le licenze Android SDK sulla macchina/runner di release e verificare `flutter doctor` completamente verde | da fare nell'ambiente release |
| 15 | Prima di attivare Oura/WHOOP diretti: ottenere approvazione provider, verificare DPA/trasferimenti, configurare OAuth/webhook e completare test revoca/cancellazione su account reali. Fino ad allora mantenere rollout server e client su `DISABLED` | bloccante solo per il claim diretto Oura/WHOOP |
| 16 | ⚠️ Attivare le push come un'unica release atomica: migrazioni `20260715123000`, `20260715133000` e `20260715134500`, function `push-dispatch`, secret provider APNs/FCM, configurazione client Firebase Android e scheduler autenticato; poi provare foreground/background/app terminata su due device reali | da fare |

---

## 1. GOOGLE PLAY

### 1.1 Scheda "Sicurezza dei dati" (Data Safety) — risposte esatte

**Raccolta dati: SÌ. Condivisione: NO. Tutti i dati cifrati in transito: SÌ.
Meccanismo di richiesta eliminazione: SÌ** → URL: pagina HTTPS pubblica del
sito/custom domain con le stesse istruzioni del GET `delete-account`.

| Tipo di dato (tassonomia Play) | Raccolto? | Condiviso? | Facoltativo? | Finalità |
|---|---|---|---|---|
| Informazioni personali → Indirizzo email | Sì | No | Sì (account opzionale) | Funzionalità dell'app, gestione account |
| Informazioni personali → Nome | Sì | No | Sì | Funzionalità dell'app (profilo, social) |
| Informazioni personali → ID utente | Sì | No | Sì | Funzionalità dell'app, gestione account |
| Messaggi → Altri messaggi in-app | Sì | No | Sì | Funzionalità dell'app (richieste social) |
| Attività nell'app → Contenuti generati dagli utenti | Sì | No | Sì | Funzionalità dell'app (card Wrapped pubblicate, backup Plus) |
| Cronologia acquisti | Sì | No | Sì | Funzionalità dell'app (stato abbonamento) |
| ID del dispositivo o altri ID | Sì, solo dopo consenso notifiche e login: Firebase Installation ID (FID) e UUID casuale dell'installazione Padelandia | No | Sì | Funzionalità dell'app (recapito e deduplicazione push) |
| Salute e fitness | **Sì** per Google Health Pro e, solo dopo attivazione, Oura/WHOOP diretti; HealthKit/Health Connect nativi restano locali | No | Sì (opt-in OAuth) | Funzionalità dell'app, riepilogo fitness |
| Posizione | No | — | — | — (mai raccolta) |
| Audio → Registrazioni vocali | No (elaborazione effimera on-device per i comandi punteggio: rientra nell'esenzione "ephemeral processing") | — | — | — |

Dichiarare inoltre: dati eliminabili dall'utente (SÌ), account eliminabile
(SÌ), nessuna pubblicità, nessun data broker, nessun tracking. Non inserire in
Play Console il dominio Supabase condiviso: rende il markup HTML come testo.

L'onboarding offre registrazione email/password anche al piano Free e una CTA
altrettanto chiara per continuare offline. La sync automatica Free è limitata a
nome, nickname, mano dominante, ruolo, livello e privacy. Il backup completo
Plus/Pro/Coach è una raccolta separata e facoltativa.

La dichiarazione deve distinguere Health Connect locale dai connettori cloud:
Google Health e gli eventuali Oura/WHOOP diretti trasferiscono al backend solo
gli aggregati autorizzati e li conservano per massimo 30 giorni. Non dichiarare
Oura/WHOOP come raccolti finché i rollout restano disattivati e nessun utente
può collegarli; aggiornare il form prima di abilitarli in produzione.

Per FCM dichiarare **Device or other IDs**: Firebase Installations genera un
identificativo per installazione e Padelandia conserva token/UUID soltanto dopo
il consenso. Finalità esclusiva App functionality; facoltativo; nessuna
condivisione pubblicitaria, tracking, Firebase Analytics o export BigQuery.

### 1.2 Dichiarazione Health Connect (obbligatoria)

Play Console → Contenuti app → **Health apps / Health & Fitness permissions**:
dichiarare sia l'uso di Health Connect sul telefono sia i permessi salute del
modulo Wear OS. Tipi: **Steps, Active calories burned, Heart rate, Exercise
sessions**; Wear OS: `ACTIVITY_RECOGNITION`, `BODY_SENSORS` e foreground
service `health` per sessione partita. Categoria d'uso: *Fitness and wellness /
attività sportiva*.

Requisiti policy (tutti già rispettati dall'app — non regredire):
- [x] Uso limitato alla funzionalità visibile all'utente (insight fitness)
- [x] Nessuna pubblicità basata su dati salute, nessuna vendita/cessione
- [x] Health Connect resta locale; Google Health API e' un opt-in Pro separato,
  dichiarato in Data Safety e cancellabile dall'utente
- [x] Informativa privacy con sezione specifica salute (sez. 6 della policy)
- [x] Richiesta permessi contestuale con spiegazione in-app
- [x] Health Connect solo lettura; Apple Watch può scrivere la sessione workout
  in Apple Salute; permessi revocabili

### 1.3 Altre dichiarazioni Play Console

- **Account deletion**: URL = pagina HTTPS pubblica stabile con le stesse
  istruzioni del GET `delete-account`; in-app path: Profilo → Gestisci account
  → Elimina account.
- **Backup deletion**: Profilo → Gestisci account → Elimina il backup cloud;
  disponibile anche dopo downgrade tramite RPC proprietaria senza accesso al
  contenuto del backup.
- **Autorizzazioni**: `RECORD_AUDIO` (comandi vocali punteggio — video/nota
  per il reviewer), permessi Health Connect (dichiarazione 1.2),
  Wear OS `ACTIVITY_RECOGNITION`, `BODY_SENSORS`, foreground service `health`,
  `POST_NOTIFICATIONS` (reminder locali e push operative social/account, solo
  dopo consenso). Nessuna posizione.
- **Target SDK**: a luglio 2026 Google richiede API 35 per nuove app/update
  mobile e API 34 per Wear OS. Padelandia usa target 36 sul telefono e 35 sul
  modulo Wear OS; ricontrollare comunque la pagina ufficiale al submit.
- **Contenuti**: nessuna pubblicità; questionario IARC → app sportiva, chat
  tra utenti moderata (social) → rating atteso PEGI 3/Everyone con
  segnalazione "interazione tra utenti".
- **Accesso app per la revisione**: fornire l'account demo (punto 0.4) con
  istruzioni: "Login → Profilo → Gestisci account; Social richiede secondo
  utente: usare account demo2 se richiesto".
- **Norme famiglie**: NON selezionare target bambini (13-). Target: 14+.
- **AI-generated content**: l'app include segnalazione nativa delle risposte
  AI (`Segnala risposta`) e tabella `assistant_reports`; indicare nel processo
  interno chi controlla le segnalazioni e con quale SLA.
- **Backup Android**: `android:allowBackup="false"` per evitare backup
  impliciti dei dati locali. Il backup cloud resta funzione Plus/Pro esplicita.

---

## 2. APPLE APP STORE

### 2.1 App Privacy ("nutrition labels") — valori esatti

Tracking: **NO** (nessun ATT necessario). Dati collegati all'identità:

| Tipo | Collegato all'utente | Finalità |
|---|---|---|
| Contact Info → Email Address | Sì | App Functionality |
| Contact Info → Name | Sì | App Functionality |
| User Content → Other User Content (card, messaggi social, backup) | Sì | App Functionality |
| Purchases → Purchase History (stato abbonamento) | Sì | App Functionality |
| Identifiers → User ID | Sì | App Functionality |
| Identifiers → Device ID | Sì, solo se abiliti le notifiche: token APNs e UUID casuale installazione | App Functionality |
| Health → Health | Sì per Google Health Pro e per eventuali Oura/WHOOP diretti attivati | App Functionality |
| Health & Fitness → Fitness | Sì per Google Health Pro e per eventuali Oura/WHOOP diretti attivati | App Functionality |

I dati HealthKit e workout restano sul dispositivo o nell'ecosistema Apple
Health. I connettori cloud Pro sono invece server-side: Google Health e, solo
dopo approvazione/rollout, Oura e WHOOP. Per questi Health e Fitness vanno
dichiarati come raccolti, collegati all'account, non usati per tracking e
destinati solo ad App Functionality.

Coerente con `ios/Runner/PrivacyInfo.xcprivacy` già nel repo (manifest con
NSPrivacyTracking=false e required-reason API dichiarate).

### 2.2 Checklist guideline critiche

- **5.1.1(v) Account deletion**: ✅ implementata in-app (doppia conferma,
  eliminazione immediata server-side). Non nascondere il bottone.
- **5.1.1(v) Account opzionale**: ✅ onboarding con email per Free e alternativa
  “Continua offline”; le funzioni locali non richiedono dati personali.
- **5.1.3 Health**: ✅ dati HealthKit mai nel cloud Padelandia/ads/terzi; usage
  description specifiche; entitlement HealthKit attivo. La watch app può
  scrivere una sessione workout in Apple Salute solo con consenso; non scrive
  dati falsi/inaccurati e non promette diagnosi mediche.
- **Analytics sportive**: ✅ calcolo deterministico post-partita sul dispositivo,
  separato dai dati salute e senza provider AI; campione e incertezza sono
  visibili. Store listing e screenshot non devono presentare momentum, clutch
  o indice Padelandia come diagnosi, previsione garantita o ranking ufficiale.
- **3.1.2 Abbonamenti**: nella pagina prodotto e nel paywall mostrare: nome
  piano, durata, prezzo/mese, cosa include; link a Privacy Policy e Terms
  (EULA) obbligatori nei metadati App Store Connect. Il paywall mostra piani,
  contenuti, restore purchases e link Privacy/Terms se configurati con
  `RALLYMATE_PRIVACY_URL` e `RALLYMATE_TERMS_URL`.
- **UI/paywall non ingannevole**: evitare dark pattern, overlay opachi,
  pulsanti di uscita nascosti, testo grigio quasi invisibile, CTA che enfatizza
  trial/offerta senza spiegare prezzo e rinnovo, o navigazione che impedisce di
  tornare alle funzioni Free.
- **2.1 Completezza**: fornire account demo nelle Review Notes + spiegare che
  watch app e Health richiedono hardware (video dimostrativo consigliato).
- **Export compliance**: ✅ `ITSAppUsesNonExemptEncryption=false` in
  Info.plist (solo HTTPS standard) — nessuna domanda in fase di submit.
- **DSA (UE)**: in App Store Connect dichiarare lo **status di trader** e
  fornire indirizzo/contatto verificati (obbligatorio per vendere in UE).
- **Privacy manifest**: ✅ `PrivacyInfo.xcprivacy` incluso nel target.

### 2.3 Checklist UI, navigazione e paywall

Questa checklist riduce il rischio di rigetti per "unclear subscription
terms", "app completeness", "dark patterns" o UX poco leggibile:

- [x] Il paywall mostra sempre un'uscita visibile: **Continua senza Premium**.
- [x] Il paywall mostra **Ripristina acquisti** senza nasconderlo in menu
  secondari.
- [x] Profilo → **Abbonamento e acquisti** espone sempre **Ripristina** e
  **Gestisci**, così reviewer e utenti non devono riaprire il paywall per
  trovare restore/disdetta.
- [x] Il paywall mostra link a **Privacy**, **Termini** e gestione/disdetta
  abbonamento. In submission gli URL devono essere pubblici, non placeholder.
- [x] I prezzi nel paywall arrivano dallo store/RevenueCat quando configurato;
  se il prodotto non è disponibile, il bottone di acquisto viene disabilitato.
- [x] Il testo spiega che l'abbonamento è auto-rinnovabile e che le funzioni
  Free restano accessibili senza acquisto.
- [x] Le CTA non promettono trial/offerte non configurate in App Store Connect o
  Play Console.
- [x] I pulsanti principali hanno contrasto alto e target touch ampi; testare
  small screen, Dynamic Type/large font, Reduce Transparency/Increase Contrast
  su iOS e Accessibility Scanner/TalkBack su Android.
- [x] Ogni schermata modale o di acquisto deve permettere ritorno chiaro tramite
  back/app bar oppure CTA esplicita.
- [ ] Prima della review: allegare o attivare gli IAP/subscription products
  nella versione App Store Connect e verificare acquisto/restore in Sandbox e
  TestFlight.
- [ ] Prima della review: testare il flusso completo con account Free, account
  Pro demo e account con abbonamento scaduto/revoked.

Pattern di rigetto emersi spesso da forum Apple Developer, RevenueCat, Reddit
`r/iOSProgramming` e `r/androiddev`:

- Restore presente solo in punti nascosti o non raggiungibile se il paywall non
  appare.
- Primo IAP/subscription non allegato alla build App Store Connect o prodotto
  ancora senza metadata/screenshot di review.
- Paywall vuoto o con prezzo assente perché lo store non restituisce prodotti.
- Trial o prezzo calcolato mostrato con più evidenza del prezzo realmente
  addebitato.
- Splash/onboarding che porta l'utente a sottoscrivere con troppi passaggi
  manipolativi o senza uscita chiara.
- Privacy/Terms non raggiungibili sempre da una schermata stabile dell'app.
- Account demo non funzionante, 2FA non bypassabile per reviewer o feature
  premium non spiegate nelle Review Notes.

Fonti operative verificate:
- Apple App Review Guidelines 2.1, 3.1.2, 4 e 5.1.1.
- Apple Auto-renewable Subscriptions e In-App Purchase / StoreKit.
- Apple Schedule 2/3: disclosure chiara di titolo, durata, prezzo, Privacy e
  Terms.
- Google Play Developer Program Policy: trial/offerte devono spiegare durata,
  prezzo, conversione a pagamento, cancel e accesso senza trial quando
  disponibile.
- Google Play Subscriptions Policy: link semplice alla gestione/cancellazione
  nell'area account o equivalente.

### 2.4 Review Notes (template da incollare)

```
Padelandia is a local-first padel scoring & training app.
Demo account: [email] / [password] (Pro plan enabled).
- Cloud features (account, social, backup) require the demo login.
- Pallino Assistant (AI) is available with the demo account; it is
  clearly disclosed as AI in-app.
- HealthKit: phone reads aggregates (steps, active energy, exercise minutes,
  avg heart rate). Apple Watch can start and save a generic workout session
  during an active match with user consent. Data never leaves the device/Apple
  Health ecosystem. Test: Profile → Fitness Pro card → "Collega"; Watch app →
  start scoring a match.
- Voice scoring uses the platform speech recognizer after an explicit tap. The
  operating system may process recognition on-device or through its own service;
  audio and transcripts are never sent to Padelandia servers.
- Apple Watch companion app syncs scoring via WatchConnectivity.
- Account deletion: Profile → Manage account → "Elimina account e dati
  cloud".
```

---

## 3. Requisiti trasversali (UE, luglio 2026)

- **GDPR**: informativa completa (docs/legal), diritti esercitabili in-app,
  registro trattamenti consigliato; DPIA leggera raccomandata per Assistant
  (trasferimento extra-UE) e social.
- **AI Act (Reg. 2024/1689), art. 50** — in vigore per i chatbot dal
  **2 agosto 2026**: obbligo di informare che si interagisce con un'AI.
  ✅ Coperto: disclosure in privacy policy sez. 7, ToS sez. 5; l'app presenta
  l'assistente come "Pallino Assistant" e consente la segnalazione in-app
  delle risposte problematiche.
- **Data Act**: non applicabile (l'app non è il produttore del wearable).
- **Codice del Consumo**: recesso digitale gestito via store (ToS sez. 4);
  garanzia contenuti digitali citata (ToS sez. 10).
- **Minori**: soglia 14 anni dichiarata; nessun targeting bambini.

---

## 4. Provider smartwatch e sportwatch

- **Apple Watch**: usare HealthKit/HKWorkoutSession solo durante una partita
  attiva e con consenso. Non salvare dati salute in iCloud o cloud Padelandia;
  non promettere diagnosi o accuratezza medica. `StartWorkoutIntent`/Siri può
  aprire un avvio scelto dall'utente; le API pubbliche non consentono di
  intercettare live un workout avviato da Allenamento o da un'altra app.
- **Wear OS / Google / Samsung Galaxy Watch**: usare Android Health Services
  come base nativa e portabile. Il foreground service `health` deve partire
  solo quando l'utente ha concesso almeno un permesso salute utile; in caso di
  permesso negato lo scoring resta locale senza workout service. Samsung Health
  Sensor SDK e' opzionale per feature future su Galaxy Watch4+ e richiede
  package/signature registrati. Il rilevamento opzionale usa
  `ACTIVITY_RECOGNITION`, un `PassiveListenerService` e notifiche normali: niente
  polling, full-screen intent o apertura forzata. Se l'esercizio appartiene a
  un'altra app, Padelandia resta in scoring-only e non lo sostituisce.
- **Garmin Connect IQ**: UUID, lista device target, scoring offline, bridge
  mobile e unit-test binary sono presenti. Prima della pubblicazione servono
  developer key/SDK custoditi fuori dal repo, esecuzione `monkeydo` interattiva
  e test su almeno un watch fisico per famiglia esportata. Il permesso `Fit`
  serve alla sessione avviata esplicitamente da Padelandia; il sub-sport Padel è
  disponibile su API 4.1.6+, con fallback Tennis/generico. Non esiste un evento
  background pubblico di inizio attività esterna. Non dichiarare supporto
  Garmin pubblico finche il modulo non supera la review Connect IQ.
- **Fitbit OS**: binari OS 4 e OS 5 separati nella stessa Gallery listing;
  nessun callback pubblico di avvio esercizio esterno. Google ha rimosso
  l'installazione di app Fitbit terze nell'EEA da giugno 2024: il modulo non va
  dichiarato disponibile in Italia. Negli eventuali paesi ancora supportati,
  app marcata "Paid", account test per la review, test su device fisico e
  messaggi peer sotto 1027 byte.
- **Google Health API / Fitbit Air**: Fitbit Air e' screenless, quindi non va
  presentato come runtime per la UI live. OAuth, token cifrati e riepiloghi
  giornalieri sono server-side e differiti; non possono generare un prompt live
  sul wearable. Servono verifica OAuth/Google Health e security assessment
  prima di superare 100 utenti. La migrazione dal Fitbit Web API legacy va
  completata prima dello shutdown annunciato per settembre 2026.
- **Tizen**: Samsung non accetta più app nuove o aggiornamenti Tizen. Padelandia
  mostra solo una guida di migrazione verso Galaxy Watch4+ con Wear OS.

## 5. Cosa NON fa l'app (da mantenere così — semplifica tutto)

- Nessun SDK pubblicitario, analytics di terze parti o tracking cross-app.
- Nessuna posizione GPS.
- Nessun dato salute nei backup generali. Solo gli aggregati esplicitamente
  autorizzati dei connettori cloud Pro raggiungono il backend, con retention
  massima di 30 giorni e cancellazione alla revoca. Oura/WHOOP restano
  disattivati fino ad approvazione e verifica contrattuale.
- Nessuna metrica salute entra nel motore Performance Intelligence; le
  analytics derivate vengono ricalcolate localmente dagli eventi sportivi.
- Nessun pagamento fuori dagli store. Gli acquisti Coach restano disattivati
  finché prodotti IAP e verifica ricevuta server-side non sono operativi.

Qualunque modifica a questi punti richiede l'aggiornamento di: privacy
policy (IT+EN), Data Safety, nutrition labels, PrivacyInfo.xcprivacy e
dichiarazione Health.

## Pallino AI context (2026-07-21)

- Pro/Coach only; synthetic **training + team** sports context may be sent with questions.
- **Never** HealthKit / Health Connect / Google Health / Oura / WHOOP samples in AI prompts.
- User toggle in Privacy: "Includi allenamenti e team".
- In-app + public privacy v1.5 disclose categories; republish HTTPS policy URL before store submit.
