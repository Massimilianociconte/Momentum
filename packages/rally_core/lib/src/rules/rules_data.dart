/// FAQ regolamento padel (dataset locale, PRD E2).
/// Basato sulle FIP Rules of Padel e sul Regolamento Tecnico Sportivo FIP.
/// Aggiornabile da remoto (JSON) senza usare LLM.
library;

import 'rules_faq.dart';

const List<RuleEntry> padelRules = [
  RuleEntry(
    id: 'scoring_base',
    question: 'Come si contano i punti nel padel?',
    answer:
        'Come nel tennis: 15, 30, 40 e game. Sul 40-40 (parità) si gioca il '
        'vantaggio oppure il punto de oro (golden point) a seconda del '
        'formato. Un set si vince a 6 game con 2 di scarto; sul 6-6 si gioca '
        'il tie-break. La partita è di norma al meglio dei 3 set.',
    keywords: [
      'punteggio',
      'punti',
      'contare',
      'game',
      'set',
      '15',
      '30',
      '40',
    ],
    source: 'FIP Rules of Padel — Punteggio',
  ),
  RuleEntry(
    id: 'golden_point',
    question: 'Come funziona il golden point (punto de oro)?',
    answer:
        'Sul 40-40 si gioca un punto secco che assegna il game. La coppia in '
        'risposta sceglie da quale lato ricevere (destra o sinistra); il '
        'ricevitore scelto deve restare su quel lato per quel punto. Non ci '
        'sono vantaggi.',
    keywords: ['golden', 'oro', 'punto', 'deuce', 'parità', '40-40', 'lato'],
    source: 'FIP Rules of Padel — Regola sul punteggio (no-advantage)',
    example:
        'Siete 40-40: chi risponde sceglie il lato. Il punto successivo '
        'decide il game.',
  ),
  RuleEntry(
    id: 'tie_break',
    question: 'Come si calcola il tie-break?',
    answer:
        'Si gioca sul 6-6. Vince chi arriva per primo a 7 punti con almeno 2 '
        'di scarto (si prosegue a oltranza: 8-6, 9-7…). Il primo giocatore '
        'serve 1 punto, poi si alternano ogni 2 punti. Si cambia campo ogni '
        '6 punti. Il set si registra 7-6.',
    keywords: ['tie-break', 'tiebreak', 'tie', 'break', '6-6', 'sette'],
    source: 'FIP Rules of Padel — Tie-break',
  ),
  RuleEntry(
    id: 'super_tie_break',
    question: 'Cos\'è il super tie-break?',
    answer:
        'In molti tornei amatoriali il terzo set è sostituito da un super '
        'tie-break a 10 punti con 2 di scarto. Chi lo vince conquista il set '
        'decisivo e la partita.',
    keywords: ['super', 'tie-break', 'terzo', 'set', 'dieci', '10'],
    source: 'Regolamenti di gara FIP — formati abbreviati',
  ),
  RuleEntry(
    id: 'serve_how',
    question: 'Come si batte il servizio?',
    answer:
        'Il servizio è sempre sotto la cintura: la palla va fatta rimbalzare '
        'a terra dietro la linea di servizio e colpita all\'altezza massima '
        'della vita. Il battitore deve avere almeno un piede a terra e non '
        'può toccare o superare la linea con i piedi. La battuta è in '
        'diagonale e la palla deve rimbalzare nel riquadro di servizio '
        'opposto.',
    keywords: ['servizio', 'battuta', 'battere', 'servire', 'cintura', 'vita'],
    source: 'FIP Rules of Padel — Il servizio',
  ),
  RuleEntry(
    id: 'serve_let',
    question: 'Quando è let (net) al servizio?',
    answer:
        'È let se la palla tocca la rete e poi rimbalza nel riquadro di '
        'servizio corretto, oppure se tocca la rete e poi il ricevitore o un '
        'oggetto prima del rimbalzo. Il servizio si ripete. Se dopo la rete '
        'la palla rimbalza correttamente e poi finisce nella griglia '
        '(rete metallica), il servizio è fallo.',
    keywords: ['let', 'net', 'rete', 'servizio', 'ripetere', 'nastro'],
    source: 'FIP Rules of Padel — Let',
    example:
        'La battuta tocca il nastro e atterra nel riquadro giusto: si '
        'ripete. Tocca il nastro e finisce sulla griglia: fallo.',
  ),
  RuleEntry(
    id: 'serve_fault',
    question: 'Quando il servizio è fallo?',
    answer:
        'È fallo se: la palla non rimbalza nel riquadro diagonale opposto; '
        'rimbalza e poi tocca la griglia metallica prima del secondo '
        'rimbalzo (nel servizio la griglia è sempre fallo); il battitore '
        'calpesta o supera la linea; colpisce la palla sopra la vita; manca '
        'la palla al tentativo di colpirla. Come nel tennis ci sono due '
        'servizi a disposizione.',
    keywords: ['fallo', 'servizio', 'griglia', 'doppio', 'errore', 'piede'],
    source: 'FIP Rules of Padel — Falli di servizio',
  ),
  RuleEntry(
    id: 'walls_own_side',
    question: 'La palla può toccare le pareti del mio campo?',
    answer:
        'Sì: dopo il rimbalzo a terra la palla può colpire le pareti del tuo '
        'campo e resta in gioco. Puoi anche colpire la palla facendola '
        'passare sopra la rete dopo che è rimbalzata sulla tua parete. La '
        'palla NON può invece toccare direttamente la tua parete prima di '
        'superare la rete quando la colpisci: sarebbe punto perso.',
    keywords: ['parete', 'pareti', 'vetro', 'muro', 'rimbalzo', 'sponda'],
    source: 'FIP Rules of Padel — Palla in gioco',
  ),
  RuleEntry(
    id: 'grid',
    question: 'La palla può toccare la griglia?',
    answer:
        'Durante lo scambio: se la palla che arriva dal campo avversario '
        'tocca prima il terreno e poi la griglia, è regolare e il gioco '
        'continua. Se invece colpisce direttamente la griglia al volo prima '
        'di rimbalzare, il punto è dell\'avversario. Nel servizio la griglia '
        'dopo il rimbalzo è comunque fallo.',
    keywords: ['griglia', 'rete', 'metallica', 'metallo', 'recinzione'],
    source: 'FIP Rules of Padel — Palla in gioco / Punto perso',
  ),
  RuleEntry(
    id: 'double_bounce',
    question: 'Quando si perde il punto?',
    answer:
        'Si perde il punto se: la palla rimbalza due volte nel proprio '
        'campo; si colpisce la palla al volo prima che superi la rete; la '
        'palla colpisce te o il tuo compagno; si tocca la rete con corpo o '
        'racchetta mentre la palla è in gioco; si colpisce la palla due '
        'volte; la palla colpita finisce direttamente sulla propria parete '
        'senza superare la rete.',
    keywords: ['perdere', 'punto', 'doppio', 'rimbalzo', 'tocca', 'corpo'],
    source: 'FIP Rules of Padel — Punto perso',
  ),
  RuleEntry(
    id: 'net_touch',
    question: 'Posso toccare la rete?',
    answer:
        'No. Se tu, la tua racchetta o qualsiasi cosa indossi tocca la rete, '
        'i pali o il campo avversario mentre la palla è in gioco, perdi il '
        'punto.',
    keywords: ['toccare', 'rete', 'palo', 'invasione', 'contatto'],
    source: 'FIP Rules of Padel — Punto perso',
  ),
  RuleEntry(
    id: 'over_net_reach',
    question: 'Posso colpire la palla oltre la rete?',
    answer:
        'In generale no: si colpisce la palla nel proprio campo. Eccezione: '
        'se la palla rimbalza nel tuo campo e torna indietro da sola verso '
        'il campo avversario (per effetto o vento), puoi invadere con la '
        'racchetta oltre la rete per colpirla, senza toccare rete o '
        'avversari. È inoltre consentito il "gancho" che accompagna la palla '
        'oltre la rete dopo averla colpita nel proprio spazio.',
    keywords: ['oltre', 'rete', 'invadere', 'sopra', 'colpire', 'gancho'],
    source: 'FIP Rules of Padel — Invasione consentita',
  ),
  RuleEntry(
    id: 'out_of_court',
    question: 'Si può giocare la palla fuori dal campo?',
    answer:
        'Sì, nei campi che lo consentono (porte aperte): se la palla supera '
        'le pareti ed esce, i giocatori possono uscire e rimandarla nel '
        'campo avversario prima del secondo rimbalzo. Il punto resta in '
        'gioco. Serve che il campo abbia gli spazi di uscita regolamentari.',
    keywords: ['fuori', 'uscire', 'porta', 'esterno', 'salida', 'recuperare'],
    source: 'FIP Rules of Padel — Gioco esterno al campo',
  ),
  RuleEntry(
    id: 'smash_out',
    question: 'Se lo smash esce dal campo che succede?',
    answer:
        'Se la palla rimbalza nel campo avversario e poi esce oltre le '
        'pareti (per 3 o per 4), il punto è di chi ha colpito, a meno che un '
        'avversario non la recuperi prima del secondo rimbalzo nei campi '
        'con uscita consentita.',
    keywords: ['smash', 'esce', 'per', 'tre', 'quattro', 'x3', 'x4', 'fuori'],
    source: 'FIP Rules of Padel — Punto vinto',
  ),
  RuleEntry(
    id: 'change_sides',
    question: 'Quando si cambia campo?',
    answer:
        'Si cambia campo quando la somma dei game del set è dispari (1°, '
        '3°, 5° game…). Nel tie-break si cambia ogni 6 punti. Tra un set e '
        'l\'altro c\'è la pausa e si riparte dal lato opposto.',
    keywords: ['cambio', 'campo', 'lato', 'dispari', 'quando'],
    source: 'FIP Rules of Padel — Cambio di campo',
  ),
  RuleEntry(
    id: 'serve_order',
    question: 'Chi serve e in che ordine?',
    answer:
        'Le coppie si alternano al servizio ogni game. All\'inizio del set '
        'ogni coppia decide quale dei due giocatori serve per primo; '
        'l\'ordine interno si mantiene per tutto il set e può cambiare solo '
        'al set successivo. Nel tie-break si segue la rotazione 1-2-2-2…',
    keywords: ['ordine', 'servizio', 'chi', 'serve', 'turno', 'rotazione'],
    source: 'FIP Rules of Padel — Ordine di servizio',
  ),
  RuleEntry(
    id: 'receive_position',
    question: 'Il ricevitore può stare dove vuole?',
    answer:
        'Il ricevitore deve trovarsi nel riquadro diagonale al battitore e '
        'la palla deve rimbalzare nel suo riquadro. Il compagno del '
        'ricevitore e il compagno del battitore possono posizionarsi '
        'ovunque nel proprio campo.',
    keywords: ['ricevitore', 'risposta', 'posizione', 'riquadro', 'diagonale'],
    source: 'FIP Rules of Padel — La risposta',
  ),
  RuleEntry(
    id: 'ball_hits_player',
    question: 'Se la palla colpisce un giocatore?',
    answer:
        'Se la palla in gioco tocca un giocatore o qualsiasi cosa indossi o '
        'porti (racchetta esclusa nel colpo regolare), il punto va agli '
        'avversari, anche se il giocatore è fuori dal campo.',
    keywords: ['colpisce', 'giocatore', 'corpo', 'tocca', 'addosso'],
    source: 'FIP Rules of Padel — Punto perso',
  ),
  RuleEntry(
    id: 'double_hit',
    question: 'Si può colpire la palla due volte?',
    answer:
        'Il doppio tocco involontario nello stesso movimento continuo è '
        'consentito (palla "accompagnata" nello stesso gesto). Due colpi '
        'distinti o un tocco di entrambi i compagni fanno perdere il punto.',
    keywords: ['doppio', 'tocco', 'due', 'volte', 'compagno'],
    source: 'FIP Rules of Padel — Colpo corretto',
  ),
  RuleEntry(
    id: 'let_point',
    question: 'Quando si ripete il punto (let)?',
    answer:
        'Il punto si ripete se un elemento esterno entra in campo o '
        'interferisce col gioco (palla da un altro campo, oggetto, '
        'interruzione), o in caso di dubbio arbitrale. Sul let di servizio '
        'si ripete solo quel servizio.',
    keywords: ['let', 'ripetere', 'interferenza', 'palla', 'esterna'],
    source: 'FIP Rules of Padel — Let',
  ),
  RuleEntry(
    id: 'court_size',
    question: 'Quanto è grande un campo da padel?',
    answer:
        'Il campo misura 20 m × 10 m, diviso a metà dalla rete. Le pareti di '
        'fondo sono alte 3 m più 1 m di griglia (4 m totali); le pareti '
        'laterali seguono il profilo regolamentare 3-2 m. La rete è alta '
        '88 cm al centro e 92 cm ai lati.',
    keywords: ['campo', 'misure', 'dimensioni', 'metri', 'rete', 'altezza'],
    source: 'FIP Rules of Padel — Il campo',
  ),
  RuleEntry(
    id: 'racket_ball',
    question: 'Che racchetta e palle si usano?',
    answer:
        'La racchetta da padel ha superficie forata, lunghezza massima 45,5 '
        'cm e spessore massimo 38 mm, con cordino di sicurezza al polso '
        '(obbligatorio). Le palle sono simili a quelle da tennis ma con '
        'pressione leggermente inferiore.',
    keywords: ['racchetta', 'pala', 'palla', 'palle', 'cordino', 'laccetto'],
    source: 'FIP Rules of Padel — Attrezzatura',
  ),
  RuleEntry(
    id: 'warmup_time',
    question: 'Quanto dura il riscaldamento e le pause?',
    answer:
        'Riscaldamento massimo 5 minuti. Tra i punti massimo 20 secondi, ai '
        'cambi di campo 90 secondi, tra i set 120 secondi. Nel tie-break i '
        'cambi campo sono senza pausa.',
    keywords: ['riscaldamento', 'pausa', 'tempo', 'secondi', 'durata'],
    source: 'FIP Rules of Padel — Gioco continuo',
  ),
  RuleEntry(
    id: 'smash_return_own_side',
    question: 'Posso rimandare la palla sulla mia parete per farla passare?',
    answer:
        'No: se colpisci la palla e questa tocca la tua parete prima di '
        'superare la rete, perdi il punto. La palla colpita deve superare '
        'direttamente la rete (o al limite toccare il nastro).',
    keywords: ['mia', 'parete', 'sponda', 'passare', 'indietro', 'boomerang'],
    source: 'FIP Rules of Padel — Punto perso',
  ),
  RuleEntry(
    id: 'who_calls',
    question: 'Chi decide i punti dubbi senza arbitro?',
    answer:
        'Nelle partite amatoriali senza arbitro decide la coppia nel cui '
        'campo è rimbalzata la palla, in buona fede. In caso di disaccordo '
        'la prassi è ripetere il punto. Nei tornei ufficiali decide '
        'l\'arbitro.',
    keywords: ['arbitro', 'dubbio', 'decidere', 'chiamata', 'contestazione'],
    source: 'Prassi FIP / fair play — partite senza arbitro',
  ),
];
