export const navItems = [
  { label: 'Come funziona', href: '/#come-funziona' },
  { label: 'Funzioni', href: '/#funzioni' },
  { label: 'Offline', href: '/#offline' },
  { label: 'FAQ', href: '/#faq' },
  { label: 'Blog', href: '/blog/' },
  { label: 'Download', href: '/download/' },
  { label: 'Supporto', href: '/supporto/' },
] as const;

export const productMoments = [
  {
    number: '01',
    title: 'Segna dal polso',
    text: 'Apple Watch e Wear OS conservano gli eventi in locale e li sincronizzano quando il collegamento torna disponibile.',
  },
  {
    number: '02',
    title: 'Rivivi ogni partita',
    text: 'Storico, andamento e analisi descrittive trasformano il punteggio in una lettura chiara del match.',
  },
  {
    number: '03',
    title: 'Allena ciò che serve',
    text: 'Sessioni guidate, minuti e sforzo percepito aiutano a dare continuità al lavoro fuori dal match.',
  },
] as const;

/**
 * Blocco "in sintesi": risposte brevi e autoconclusive, pensate per essere
 * estratte da motori di ricerca e assistenti generativi (GEO).
 */
export const factSheet = [
  {
    term: 'Che cos’è Momentum',
    definition:
      'Un’app per il padel che unisce segnapunti offline, companion per Apple Watch e Wear OS e analisi descrittive delle partite.',
  },
  {
    term: 'A chi serve',
    definition:
      'A chi gioca a padel e vuole un punteggio affidabile in campo e uno storico leggibile dopo la partita, senza dipendere dalla rete.',
  },
  {
    term: 'Piattaforme',
    definition:
      'iOS e Android, con companion nativi per Apple Watch e per gli smartwatch Wear OS.',
  },
  {
    term: 'Serve un account',
    definition:
      'No per segnapunti, undo e storico locale. Le funzioni connesse richiedono account e dipendono anche da configurazione cloud, piano e rollout.',
  },
  {
    term: 'Funziona offline',
    definition:
      'Sì. Il punteggio è registrato come sequenza di eventi sul dispositivo e viene riallineato quando la connessione torna.',
  },
  {
    term: 'Formati di gioco',
    definition:
      'La build attuale include Star Point FIP 2026, golden point, vantaggi, tie-break, super tie-break, set singolo e allenamento libero.',
  },
] as const;

/** Griglia funzioni visibile in pagina: allineata al featureList dello schema. */
export const coreFeatures = [
  {
    icon: 'watch',
    title: 'Segnapunti da polso',
    text: 'Un tap per punto su Apple Watch e Wear OS. Il telefono può restare in borsa per tutta la partita.',
  },
  {
    icon: 'undo',
    title: 'Undo che ricostruisce',
    text: 'Ogni correzione è un evento del motore di punteggio: l’undo funziona anche oltre il confine di game e set.',
  },
  {
    icon: 'offline',
    title: 'Offline-first davvero',
    text: 'Segnapunti, pausa e ripresa, storico locale e FAQ regole restano disponibili senza connessione.',
  },
  {
    icon: 'chart',
    title: 'Analisi descrittive',
    text: 'Andamento, pressione e rendimento con campione e limiti dichiarati. Nessun ranking inventato.',
  },
  {
    icon: 'book',
    title: 'Regole senza discussioni',
    text: 'FAQ locali su Star Point, golden point, tie-break, servizio e cambio campo, con fonti indicate.',
  },
  {
    icon: 'spark',
    title: 'Allenamento continuo',
    text: 'Sessioni guidate, minuti e sforzo percepito per dare continuità al lavoro fuori dal campo.',
  },
] as const;

/** Passi della HowTo "come segnare una partita di padel". */
export const howToSteps = [
  {
    title: 'Imposta il formato',
    text: 'Scegli Star Point, golden point o vantaggi, numero di set e tipo di tie-break. La configurazione resta salvata per la prossima partita.',
  },
  {
    title: 'Avvia dal polso o dal telefono',
    text: 'La partita parte da qualunque dispositivo. Gli eventi vengono registrati in locale, anche senza rete nel circolo.',
  },
  {
    title: 'Segna un punto per volta',
    text: 'Un tap assegna il punto alla coppia. Momentum calcola game, set e cambi campo e mostra sempre lo stato corrente.',
  },
  {
    title: 'Correggi con l’undo',
    text: 'Se il punto è stato assegnato alla coppia sbagliata, l’undo ricostruisce lo stato corretto anche a game concluso.',
  },
  {
    title: 'Chiudi e rileggi la partita',
    text: 'A fine match trovi il riepilogo nello storico: andamento, momenti di pressione e dati descrittivi del match.',
  },
] as const;

/** Cosa resta locale e cosa richiede rete: tabella molto citabile. */
export const capabilityMatrix = [
  { capability: 'Segnapunti, undo, pausa e ripresa', offline: true, note: 'Locale' },
  { capability: 'Storico partite sul dispositivo', offline: true, note: 'Locale' },
  { capability: 'FAQ regole del padel', offline: true, note: 'Locale' },
  { capability: 'Sincronizzazione telefono ↔ smartwatch', offline: true, note: 'In coda, poi riallineata' },
  {
    capability: 'Account e profilo sincronizzato',
    offline: false,
    note: 'Funzione connessa, soggetta a rollout',
  },
  {
    capability: 'Backup cloud e multi-dispositivo',
    offline: false,
    note: 'Condizionale: account, cloud e piano idoneo',
  },
  {
    capability: 'Funzioni social e Duo Mode',
    offline: false,
    note: 'Non promosse al lancio; rollout e piano idoneo',
  },
  {
    capability: 'Assistente generativo sulle regole',
    offline: false,
    note: 'Condizionale: rete, cloud e piano idoneo',
  },
] as const;

/** Glossario padel: contenuto informativo per query di ricerca e assistenti. */
export const glossary = [
  {
    term: 'Golden point',
    definition:
      'Punto decisivo giocato sul 40-40 al posto dei vantaggi: chi lo vince conquista il game. La coppia in risposta sceglie il lato di ricezione.',
  },
  {
    term: 'Star Point',
    definition:
      'Metodo FIP in vigore dal 2026: dopo due cicli di vantaggio e ritorno alla parità si gioca un punto decisivo. La coppia in risposta sceglie il lato senza cambiare le posizioni; nei misti riceve chi ha lo stesso sesso del battitore. Momentum lo supporta offline e sui companion aggiornati per Apple Watch e Wear OS.',
  },
  {
    term: 'Vantaggi',
    definition:
      'Formato classico in cui dal 40-40 serve conquistare due punti consecutivi per chiudere il game.',
  },
  {
    term: 'Tie-break',
    definition:
      'Si gioca sul 6-6 di un set e arriva a 7 punti con almeno due di margine. Il servizio cambia dopo il primo punto e poi ogni due punti.',
  },
  {
    term: 'Super tie-break',
    definition:
      'Gioco decisivo a 10 punti, con almeno due di margine, usato al posto del terzo set per accorciare la durata della partita.',
  },
  {
    term: 'Let',
    definition:
      'Servizio da ripetere: la palla tocca il nastro e cade regolarmente nel quadrato di servizio avversario senza colpire prima la rete metallica.',
  },
  {
    term: 'Punteggio del padel',
    definition:
      'La progressione base è 15, 30, 40 e game. Le regole FIP 2026 prevedono tre metodi per chiudere la parità: vantaggi, Star Point e golden point.',
  },
] as const;

export const rulesReviewedOn = '27 luglio 2026';

export const ruleSources = [
  {
    label: 'FIP · Rules of Padel, revisione applicabile dal 1 gennaio 2026',
    href: 'https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel-1.pdf',
  },
  {
    label: 'FIP · Introduzione dello Star Point',
    href: 'https://www.padelfip.com/2025/12/between-innovation-and-tradition-introducing-the-star-point-the-scoring-system-that-appeals-to-everyone/',
  },
  {
    label: 'CUPRA FIP Tour · Official Rulebook 2026',
    href: 'https://www.padelfip.com/wp-content/uploads/2025/03/Cupra-FIP-Tour-Rulebook_EN-2.pdf',
  },
  {
    label: 'Premier Padel · Official Rulebook 2026',
    href: 'https://www.padelfip.com/wp-content/uploads/2025/03/Premier-Padel-Rulebook-Men%C2%B4s_EN.pdf',
  },
] as const;

export const supportRows = [
  {
    icon: 'book',
    title: 'Regole senza dubbi',
    text: 'FAQ rapide su punteggio, Star Point, servizio, tie-break e golden point.',
    href: '/supporto/#regole',
  },
  {
    icon: 'headset',
    title: 'Supporto tecnico',
    text: 'Guide per app, Apple Watch, Wear OS e sincronizzazione.',
    href: '/supporto/#problemi',
  },
  {
    icon: 'users',
    title: 'Costruiamola insieme',
    text: 'Segnala un problema o proponi la prossima feature.',
    href: '/supporto/#richiesta',
  },
] as const;

export const faqs = [
  {
    category: 'Primi passi',
    question: 'Momentum funziona senza internet?',
    answer:
      'Sì, le funzioni essenziali — segnapunti, undo, pausa e ripresa, storico locale e FAQ regole — sono progettate per funzionare offline. Le funzioni cloud, social, Duo Mode e AI, se abilitate per build, piano e rollout, richiedono invece account e connessione.',
  },
  {
    category: 'Primi passi',
    question: 'Serve un account per usare Momentum?',
    answer:
      'No per il segnapunti e le principali funzioni locali. Un account è necessario soltanto per i servizi connessi quando disponibili; backup, social e altre esperienze multi-dispositivo dipendono anche dalla configurazione cloud, dal piano e dal rollout.',
  },
  {
    category: 'Primi passi',
    question: 'Su quali dispositivi si usa Momentum?',
    answer:
      'Momentum è un’app per smartphone iOS e Android con companion nativi per Apple Watch e per smartwatch Wear OS. Telefono e orologio condividono la stessa partita e si riallineano quando tornano in collegamento.',
  },
  {
    category: 'Punteggio',
    question: 'Quali formati di partita supporta?',
    answer:
      'La build attuale include Star Point FIP 2026, golden point, vantaggi, tie-break, super tie-break, set singolo e allenamento libero. Lo stesso formato viene conservato nel flusso offline tra telefono e companion aggiornati per Apple Watch e Wear OS.',
  },
  {
    category: 'Punteggio',
    question: 'Come funziona lo Star Point nel padel?',
    answer:
      'Sul primo 40-40 si gioca il vantaggio 1; se viene annullato si torna alla parità 2 e si gioca il vantaggio 2. Se anche questo viene annullato, la parità 3 introduce lo Star Point: il punto successivo assegna il game. La coppia in risposta sceglie il lato senza cambiare le posizioni; nei misti riceve chi ha lo stesso sesso del battitore.',
  },
  {
    category: 'Punteggio',
    question: 'Posso annullare un punto anche dopo la fine di un game o set?',
    answer:
      'Sì. L’undo è un evento del motore di punteggio e può ricostruire correttamente lo stato anche oltre il confine di un game o di un set.',
  },
  {
    category: 'Punteggio',
    question: 'Come si contano i punti nel padel?',
    answer:
      'La progressione base è 15, 30, 40 e game. Un set standard arriva a 6 game con due di scarto e tie-break sul 6-6. Le regole FIP 2026 prevedono tre opzioni alla parità: vantaggi, Star Point e golden point; il torneo o il formato scelto stabilisce quale usare.',
  },
  {
    category: 'Smartwatch',
    question: 'Cosa succede se watch e telefono perdono la connessione?',
    answer:
      'Gli eventi del punteggio restano in coda sul dispositivo. Quando il collegamento torna disponibile, Momentum riallinea telefono e watch evitando di duplicare gli eventi già ricevuti.',
  },
  {
    category: 'Smartwatch',
    question: 'Quali smartwatch sono supportati?',
    answer:
      'Il prodotto include companion native per Apple Watch e dispositivi Wear OS. La compatibilità dipende da sistema operativo, modello e configurazione: prima della pubblicazione verrà mantenuta una matrice aggiornata per i dispositivi verificati.',
  },
  {
    category: 'Smartwatch',
    question: 'Posso usare Momentum al polso durante un torneo?',
    answer:
      'Non darlo per scontato: avere la companion installata non equivale al permesso di usarla in gara. I rulebook 2026 del CUPRA FIP Tour e di Premier Padel vietano a giocatori e allenatori l’uso di dispositivi elettronici dall’inizio dello scambio — nel testo Premier Padel dal palleggio di riscaldamento — fino alla fine del match, salvo approvazione del Supervisor o del Referee del torneo. Chiedi al giudice di gara prima di scendere in campo.',
  },
  {
    category: 'Statistiche',
    question: 'Come vengono calcolate le statistiche?',
    answer:
      'Le analisi derivano dagli eventi di punteggio e descrivono andamento, pressione, rendimento e campione disponibile. Non riconoscono automaticamente i colpi e non costituiscono un ranking federale o una previsione garantita.',
  },
  {
    category: 'Privacy',
    question: 'I comandi vocali ascoltano continuamente?',
    answer:
      'No. Lo scoring vocale è push-to-talk in italiano: l’ascolto parte solo quando lo attivi. Non è un sistema di ascolto ambientale continuo.',
  },
  {
    category: 'Privacy',
    question: 'Momentum pubblica la mia posizione precisa?',
    answer:
      'No. Le funzioni social sono facoltative e usano informazioni di area solo quando il profilo è reso visibile. La posizione precisa non viene mostrata pubblicamente agli altri giocatori.',
  },
  {
    category: 'Privacy',
    question: 'Come elimino account e dati cloud?',
    answer:
      'L’eliminazione si avvia dall’app, in Profilo → Gestisci account → Elimina account e dati cloud. L’operazione è immediata e permanente per account e dati cloud; la procedura completa è descritta nella pagina dedicata del sito.',
  },
  {
    category: 'Disponibilità',
    question: 'Garmin, Fitbit, Oura e WHOOP sono già disponibili?',
    answer:
      'Non vengono promessi come disponibili al lancio. Alcune integrazioni sono in sviluppo o soggette a store, provider e verifica hardware; la landing pubblicherà solo le compatibilità confermate.',
  },
] as const;

export const homeFaqs = faqs.slice(0, 6);

export const softwareFeatureList = [
  'Segnapunti padel offline-first',
  'Star Point FIP 2026, golden point e vantaggi',
  'Undo, pausa e ripresa della partita',
  'Companion Apple Watch e Wear OS',
  'Storico e analisi descrittive',
  'FAQ regole con fonti indicate',
  'Sessioni di allenamento guidate',
] as const;

export const footerGroups = [
  {
    title: 'Prodotto',
    links: [
      { label: 'Come funziona', href: '/#come-funziona' },
      { label: 'Funzioni', href: '/#funzioni' },
      { label: 'Offline-first', href: '/#offline' },
      { label: 'Scarica la preview Android', href: '/download/' },
      { label: 'Blog', href: '/blog/' },
      { label: 'Domande frequenti', href: '/#faq' },
    ],
  },
  {
    title: 'Supporto',
    links: [
      { label: 'Centro supporto', href: '/supporto/' },
      { label: 'Regole del padel', href: '/supporto/#regole' },
      { label: 'Glossario', href: '/supporto/#glossario' },
      { label: 'Proponi una feature', href: '/supporto/#richiesta' },
    ],
  },
  {
    title: 'Legale',
    links: [
      { label: 'Privacy', href: '/privacy/' },
      { label: 'Termini', href: '/termini/' },
      { label: 'Cookie policy', href: '/cookie/' },
      { label: 'Elimina account', href: '/elimina-account/' },
    ],
  },
] as const;
