/// FAQ regolamento padel (dataset locale, PRD E2).
///
/// Fonte primaria: FIP Rules of Padel, revisione di applicazione 01.01.2026
/// (adottata all'Assemblea Generale di Acapulco del 28.11.2025).
/// Le voci che riguardano i circuiti citano i rispettivi rulebook 2026.
/// Ogni voce porta fonte, numero di regola ([RuleEntry.ruleRef]) e edizione
/// ([padelRulesEdition]). Aggiornabile da remoto (JSON) senza usare LLM.
library;

import 'rules_faq.dart';

const _fip = 'FIP Rules of Padel';

const List<RuleEntry> padelRules = [
  RuleEntry(
    id: 'scoring_base',
    question: 'Come si contano i punti nel padel?',
    answer:
        'Come nel tennis: 15, 30, 40 e game. Sul 40-40 (parità) si gioca il '
        'vantaggio, lo Star Point oppure il punto de oro (Golden Point) a '
        'seconda dell\'opzione scelta prima del match. Un set si vince a 6 '
        'game con almeno 2 di scarto; sul 5-5 si gioca fino al 7-5 e sul 6-6 '
        'si gioca il tie-break. La partita è di norma al meglio dei 3 set.',
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
    source: '$_fip — Regola 1, Punteggio in un game',
    ruleRef: 'Regola 1, opzioni 1-3 e punti 2-3',
  ),
  RuleEntry(
    id: 'star_point',
    question: 'Come funziona lo Star Point FIP?',
    answer:
        'È l\'opzione 2 della Regola 1. Sul primo 40-40 si chiama parità 1: '
        'il punto seguente assegna vantaggio 1. Se chi è in vantaggio perde '
        'il punto si torna a parità 2; seguono allo stesso modo vantaggio 2 '
        'e, se viene annullato, parità 3. A parità 3 si gioca lo Star Point: '
        'la coppia in risposta sceglie se ricevere da destra o da sinistra, '
        'ma i due giocatori NON possono scambiarsi le posizioni per ricevere '
        'il punto decisivo. Chi vince lo Star Point vince il game. Nel misto '
        'il punto decisivo lo riceve una persona dello stesso sesso di chi '
        'serve.',
    keywords: [
      'star',
      'star point',
      'parità 1',
      'parità 2',
      'parità 3',
      'deuce 1',
      'deuce 2',
      'deuce 3',
      'vantaggio 1',
      'vantaggio 2',
      'decisivo',
    ],
    source: '$_fip — Regola 1, Opzione 2: Star Point',
    ruleRef: 'Regola 1, Opzione 2, punti 1-2',
    example:
        'Parità 1, vantaggio 1, parità 2, vantaggio 2, parità 3: il punto '
        'successivo è lo Star Point e decide il game.',
  ),
  RuleEntry(
    id: 'golden_point',
    question: 'Come funziona il golden point (punto de oro)?',
    answer:
        'È l\'opzione 3 della Regola 1, il punteggio "senza vantaggi". Si '
        'contano 15, 30, 40 e game; se entrambe le coppie arrivano a tre '
        'punti si chiama parità e si gioca un unico punto decisivo che '
        'assegna il game. La coppia in risposta sceglie se ricevere da destra '
        'o da sinistra, ma i due giocatori NON possono scambiarsi le '
        'posizioni per ricevere il punto decisivo. Nel misto il punto '
        'decisivo lo riceve una persona dello stesso sesso di chi serve. A '
        'differenza dello Star Point non esiste alcun ciclo di vantaggi: si '
        'decide subito al primo 40-40.',
    keywords: ['golden', 'oro', 'punto', 'deuce', 'parità', '40-40', 'lato'],
    source: '$_fip — Regola 1, Opzione 3: Golden Point',
    ruleRef: 'Regola 1, Opzione 3, punti 1-3',
    example:
        'Siete 40-40: chi risponde sceglie il lato senza cambiare posizione '
        'col compagno. Il punto successivo decide il game.',
  ),
  RuleEntry(
    id: 'tie_break',
    question: 'Come si calcola il tie-break?',
    answer:
        'Si gioca sul 6-6. Vince chi arriva per primo a 7 punti con almeno 2 '
        'di scarto (si prosegue a oltranza: 8-6, 9-7…). Inizia a servire chi '
        'aveva il turno secondo l\'ordine del set e serve un solo punto, da '
        'destra; poi si alternano due punti a testa, iniziando da sinistra. '
        'Si cambia campo ogni 6 punti. Il set si registra 7-6 e il set '
        'successivo lo inizia al servizio il giocatore della coppia che non '
        'aveva iniziato a servire il tie-break.',
    keywords: ['tie-break', 'tiebreak', 'tie', 'break', '6-6', 'sette'],
    source: '$_fip — Regola 1, Tie-break',
    ruleRef: 'Regola 1, Tie-break, punti 1-5',
  ),
  RuleEntry(
    id: 'super_tie_break',
    question: 'Cos\'è il super tie-break?',
    answer:
        'È uno dei metodi di punteggio alternativi previsti dalla Regola 1: '
        'sul risultato di un set pari, al posto dell\'ultimo set si gioca un '
        'super tie-break a 10 punti con almeno 2 di scarto. Chi lo vince '
        'vince il match. Va stabilito prima dell\'inizio della partita.',
    keywords: ['super', 'tie-break', 'terzo', 'set', 'dieci', '10'],
    source: '$_fip — Regola 1, Metodi di punteggio alternativi',
    ruleRef: 'Regola 1, Metodi alternativi, punto 1(c)',
  ),
  RuleEntry(
    id: 'mini_set',
    question: 'Cos\'è il mini-set a 4 game?',
    answer:
        'È un metodo di punteggio alternativo previsto dalla Regola 1: il set '
        'si vince a 4 game con almeno 2 di scarto. Se le due coppie arrivano '
        'a 4 game pari si gioca il tie-break. Serve per accorciare la durata '
        'delle partite e va stabilito prima dell\'inizio del match.',
    keywords: [
      'mini',
      'mini-set',
      'quattro',
      '4',
      'game',
      'set',
      'corto',
      'breve',
    ],
    source: '$_fip — Regola 1, Metodi di punteggio alternativi',
    ruleRef: 'Regola 1, Metodi alternativi, punto 1(a)',
    example: 'Sul 4-4 si gioca il tie-break; il mini-set si chiude 5-4.',
  ),
  RuleEntry(
    id: 'match_tie_break_7',
    question: 'Cos\'è il tie-break decisivo a 7 punti?',
    answer:
        'È un metodo di punteggio alternativo previsto dalla Regola 1: sul '
        'risultato di un set pari, al posto dell\'ultimo set si gioca un '
        'tie-break a 7 punti con almeno 2 di scarto, che è definitivo e '
        'decide il match. È la versione breve del super tie-break a 10 e va '
        'stabilito prima dell\'inizio della partita.',
    keywords: [
      'tie-break',
      'decisivo',
      'sette',
      '7',
      'match',
      'ultimo',
      'set',
    ],
    source: '$_fip — Regola 1, Metodi di punteggio alternativi',
    ruleRef: 'Regola 1, Metodi alternativi, punto 1(b)',
  ),
  RuleEntry(
    id: 'third_set_no_tiebreak',
    question: 'Si può giocare il terzo set senza tie-break?',
    answer:
        'Sì, se stabilito in anticipo. La Regola 1 prevede che, sul risultato '
        'di un set pari, il terzo set possa essere giocato senza tie-break: '
        'in quel caso sul 6-6 si continua finché una coppia non prende 2 game '
        'di vantaggio (7-5 nei game successivi, 8-6, 9-7…). Non è il '
        'comportamento predefinito: senza accordo preventivo sul 6-6 si gioca '
        'il tie-break.',
    keywords: [
      'terzo',
      'set',
      'senza',
      'tie-break',
      'vantaggi',
      'oltranza',
      'advantage',
    ],
    source: '$_fip — Regola 1, Opzione 1: Vantaggi',
    ruleRef: 'Regola 1, Opzione 1, punto 4',
  ),
  RuleEntry(
    id: 'serve_how',
    question: 'Come si batte il servizio?',
    answer:
        'Il battitore deve stare con almeno un piede dietro la linea di '
        'servizio, tra il prolungamento immaginario della linea centrale e la '
        'parete laterale, e restarci finché la palla non è stata servita. '
        'Deve far rimbalzare la palla a terra nel proprio riquadro: la palla '
        'non può superare la linea di servizio (né la linea centrale '
        'immaginaria) prima di essere colpita. Il colpo va dato all\'altezza '
        'della vita o sotto, con almeno un piede a contatto col terreno. La '
        'battuta è in diagonale e la palla deve rimbalzare nel riquadro di '
        'ricezione opposto: si inizia servendo verso il riquadro alla '
        'sinistra del ricevente e poi si alterna.',
    keywords: ['servizio', 'battuta', 'battere', 'servire', 'cintura', 'vita'],
    source: '$_fip — Regola 6, Il servizio',
    ruleRef: 'Regola 6, punti 1-5',
  ),
  RuleEntry(
    id: 'serve_let',
    question: 'Quando è let (net) al servizio?',
    answer:
        'Il servizio è "net" se la palla tocca la rete o i pali e poi '
        'atterra nel riquadro di ricezione corretto, purché non tocchi la '
        'griglia metallica prima del secondo rimbalzo, oppure se dopo aver '
        'toccato rete o pali colpisce un giocatore o un oggetto indossato o '
        'portato. Il servizio si ripete anche se la palla è servita quando il '
        'ricevitore non era pronto. Attenzione alla differenza tra i due '
        'servizi: se il let capita sul primo servizio si ripete il punto '
        'completo e il battitore ha di nuovo due servizi; se capita sul '
        'secondo si ripete solo il secondo servizio.',
    keywords: ['let', 'net', 'rete', 'servizio', 'ripetere', 'nastro'],
    source: '$_fip — Regola 9, Ripetizione o "let" e servizio "net"',
    ruleRef: 'Regola 9, punti 1-2',
    example:
        'Let sul primo servizio: due servizi nuovi. Let sul secondo: si '
        'ripete solo il secondo.',
  ),
  RuleEntry(
    id: 'serve_fault',
    question: 'Quando il servizio è fallo?',
    answer:
        'È fallo se: il battitore viola una delle prescrizioni sul servizio '
        '(posizione dei piedi, rimbalzo nel proprio riquadro, colpo sopra la '
        'vita); manca la palla nel tentativo di colpirla; la palla rimbalza '
        'fuori dal riquadro di ricezione (le righe sono buone); la palla '
        'colpisce il battitore, il suo compagno o un oggetto da loro '
        'indossato o portato; la palla rimbalza nel riquadro e poi tocca la '
        'griglia metallica prima del secondo rimbalzo; la palla rimbalza nel '
        'riquadro ed esce direttamente dalle porte di un campo senza zona di '
        'sicurezza e quindi senza gioco esterno autorizzato. Ci sono due '
        'servizi a disposizione e due falli consecutivi fanno perdere il '
        'punto.',
    keywords: ['fallo', 'servizio', 'griglia', 'doppio', 'errore', 'piede'],
    source: '$_fip — Regola 7, Fallo di servizio',
    ruleRef: 'Regola 7, punto 1(a)-(f); Regola 13.1(q)',
  ),
  RuleEntry(
    id: 'serve_order',
    question: 'Chi serve e in che ordine? Cosa succede se sbaglio turno?',
    answer:
        'Le coppie si alternano al servizio ogni game. Prima di ogni set ogni '
        'coppia decide quale dei due giocatori serve per primo; stabilito '
        'l\'ordine non si può cambiare fino all\'inizio del set successivo. '
        'Se un giocatore serve fuori turno, appena ci si accorge dell\'errore '
        'deve servire chi avrebbe dovuto farlo: i punti giocati restano '
        'validi e un eventuale fallo di primo servizio non si conta. Se il '
        'game è già finito quando l\'errore viene scoperto, l\'ordine sbagliato '
        'resta fino alla fine del set. Se il servizio è battuto per '
        'distrazione dal lato sbagliato, si corregge appena ci si accorge: i '
        'punti restano validi e il fallo di primo servizio va invece '
        'conteggiato.',
    keywords: ['ordine', 'servizio', 'chi', 'serve', 'turno', 'rotazione'],
    source: '$_fip — Regola 6, Il servizio',
    ruleRef: 'Regola 6, punti 7-9',
  ),
  RuleEntry(
    id: 'receive_order',
    question: 'In che ordine si riceve e cosa succede se si sbaglia?',
    answer:
        'Nel primo game di ogni set la coppia in risposta decide chi riceve '
        'per primo: quel giocatore riceverà il primo servizio di ogni game '
        'fino alla fine del set. Durante il game i due compagni ricevono a '
        'turno alternato e l\'ordine, una volta stabilito, non può essere '
        'cambiato per quel set o tie-break, ma può cambiare all\'inizio di un '
        'set nuovo. Se durante un game o un tie-break l\'ordine di ricezione '
        'viene alterato, si continua così fino alla fine di quel game o '
        'tie-break; dal game successivo si torna alle posizioni scelte '
        'inizialmente.',
    keywords: [
      'ordine',
      'ricezione',
      'ricevere',
      'risposta',
      'turno',
      'errore',
      'correzione',
    ],
    source: '$_fip — Regola 8, Risposta al servizio',
    ruleRef: 'Regola 8, punti 2-4',
  ),
  RuleEntry(
    id: 'receive_position',
    question: 'Il ricevitore può stare dove vuole?',
    answer:
        'Sì. Il ricevitore può stare in qualsiasi punto del proprio campo, '
        'come il suo compagno e il compagno del battitore: nessuno è '
        'obbligato a posizionarsi dentro un riquadro. Riceve il giocatore che '
        'si trova diagonalmente di fronte al battitore, ed è la palla servita '
        'a dover rimbalzare nel riquadro di ricezione in diagonale. Il '
        'ricevitore deve aspettare che la palla rimbalzi nel proprio riquadro '
        'e colpirla prima del secondo rimbalzo. Unica eccezione: sul punto '
        'decisivo di Star Point e Golden Point i due giocatori in risposta '
        'non possono scambiarsi le posizioni.',
    keywords: ['ricevitore', 'risposta', 'posizione', 'riquadro', 'diagonale'],
    source: '$_fip — Regola 3, Posizione dei giocatori',
    ruleRef: 'Regola 3, punti 1-2; Regola 8, punto 1',
  ),
  RuleEntry(
    id: 'walls_own_side',
    question: 'La palla può toccare le pareti del mio campo?',
    answer:
        'Sì, in due modi diversi. Dopo che la palla è rimbalzata a terra nel '
        'tuo campo puoi lasciarla andare sulle tue pareti e giocarla dopo il '
        'rimbalzo sul vetro. Ed è una risposta valida anche colpire la palla '
        'contro una parete del tuo campo per farla passare di là: la Regola '
        '14 considera corretta la risposta in cui la palla, dopo essere stata '
        'colpita, tocca prima la parete del proprio campo e poi rimbalza nel '
        'campo avversario. I limiti sono altri: la palla che colpisci non '
        'può toccare la griglia metallica o il terreno del tuo campo, e non '
        'può finire direttamente sulle pareti o sulla griglia avversarie '
        'senza rimbalzare prima nel campo avversario.',
    keywords: ['parete', 'pareti', 'vetro', 'muro', 'rimbalzo', 'sponda'],
    source: '$_fip — Regola 14, Risposta corretta',
    ruleRef: 'Regola 14.1(b); limiti in Regola 13.1(g) e 13.1(l)',
    example:
        'Sei schiacciato in fondo: colpisci la palla contro il tuo vetro e '
        'quella scavalca la rete rimbalzando di là. Punto regolare.',
  ),
  RuleEntry(
    id: 'smash_return_own_side',
    question: 'Posso rimandare la palla sulla mia parete per farla passare?',
    answer:
        'Sì: è espressamente una risposta corretta. Puoi colpire la palla '
        'contro la parete del tuo campo purché poi rimbalzi nel campo '
        'avversario. Perdi invece il punto se la palla che hai colpito tocca '
        'la griglia metallica del tuo campo, il terreno del tuo campo o un '
        'oggetto estraneo appoggiato per terra dalla tua parte, e se dalla '
        'tua parete finisce direttamente sulle pareti o sulla griglia '
        'avversarie senza rimbalzare prima nel campo avversario.',
    keywords: ['mia', 'parete', 'sponda', 'passare', 'indietro', 'boomerang'],
    source: '$_fip — Regola 14, Risposta corretta',
    ruleRef: 'Regola 14.1(b); Regola 13.1(g) e 13.1(l)',
  ),
  RuleEntry(
    id: 'grid',
    question: 'La palla può toccare la griglia?',
    answer:
        'Dipende da chi la manda. Se la palla arriva dal campo avversario, '
        'rimbalza prima a terra nel tuo campo e poi tocca la griglia (o una '
        'parete), resta in gioco e va rigiocata prima del secondo rimbalzo. '
        'Se invece sei tu a colpire la palla e questa finisce sulla griglia '
        'del tuo campo, perdi il punto. Nel servizio, la palla che rimbalza '
        'nel riquadro e poi tocca la griglia prima del secondo rimbalzo è '
        'fallo.',
    keywords: ['griglia', 'rete', 'metallica', 'metallo', 'recinzione'],
    source: '$_fip — Regole 12, 13 e 7',
    ruleRef: 'Regola 12, punti 3-4; Regola 13.1(l); Regola 7.1(e)',
  ),
  RuleEntry(
    id: 'double_bounce',
    question: 'Quando si perde il punto?',
    answer:
        'Si perde il punto, tra gli altri casi, se: la palla rimbalza due '
        'volte prima di essere rinviata; si colpisce la palla prima che abbia '
        'superato la rete; tu, la tua racchetta o qualcosa che indossi '
        'toccate la rete, i pali, il cavo di tensione o il campo avversario '
        'mentre la palla è in gioco; la palla dopo che l\'hai colpita tocca '
        'te o il tuo compagno; colpisci la palla due volte; la palla che hai '
        'colpito tocca la griglia metallica o il terreno del tuo campo; '
        'colpite la palla in due contemporaneamente o uno dopo l\'altro; si '
        'salta oltre la rete mentre il punto è in gioco; si commettono due '
        'falli di servizio consecutivi; si rompe il cordino di sicurezza o si '
        'lascia cadere la racchetta.',
    keywords: ['perdere', 'punto', 'doppio', 'rimbalzo', 'tocca', 'corpo'],
    source: '$_fip — Regola 13, Punto perso',
    ruleRef: 'Regola 13.1(a)-(r)',
  ),
  RuleEntry(
    id: 'net_touch',
    question: 'Posso toccare la rete?',
    answer:
        'No. Se tu, la tua racchetta o qualsiasi cosa indossi o porti tocca '
        'la rete, i pali, il cavo di tensione o una qualsiasi parte del campo '
        'avversario mentre la palla è in gioco, perdi il punto. Nel gioco '
        'esterno autorizzato il palo verticale che divide le porte è '
        'considerato zona neutra sopra 0,92 m: lì i giocatori possono '
        'toccarlo o aggrapparsi.',
    keywords: ['toccare', 'rete', 'palo', 'invasione', 'contatto'],
    source: '$_fip — Regola 13, Punto perso',
    ruleRef: 'Regola 13.1(a)-(b)',
  ),
  RuleEntry(
    id: 'over_net_reach',
    question: 'Posso colpire la palla oltre la rete?',
    answer:
        'In generale no: si colpisce la palla nel proprio campo. Eccezione '
        'prevista dalla Regola 14: se la palla rimbalza correttamente nel '
        'campo avversario e per effetto o vento torna indietro verso il campo '
        'di chi ha servito il colpo, l\'avversario può giocarla, purché né '
        'lui né i suoi indumenti o la racchetta tocchino la rete, i pali o il '
        'campo avversario. È inoltre considerata corretta la risposta con '
        'doppio contatto nello stesso movimento continuo, se la traiettoria '
        'naturale della palla non cambia in modo sostanziale.',
    keywords: ['oltre', 'rete', 'invadere', 'sopra', 'colpire', 'gancho'],
    source: '$_fip — Regola 14, Risposta corretta',
    ruleRef: 'Regola 14.1(g)-(h)',
  ),
  RuleEntry(
    id: 'out_of_court',
    question: 'Si può giocare la palla fuori dal campo?',
    answer:
        'Solo nei campi autorizzati. La Regola 16 consente di uscire dal '
        'campo per giocare la palla soltanto se l\'impianto rispetta le '
        'condizioni previste per zona di sicurezza e gioco esterno: due '
        'accessi per lato, nessun ostacolo in un\'area di almeno 3 metri di '
        'larghezza (4 raccomandati) e 4 di lunghezza, alta almeno 3 metri. '
        'Anche i pali della luce devono stare fuori da quest\'area: se '
        'ricadono nella zona di sicurezza il gioco esterno non è ammesso. Nei '
        'campi senza gioco esterno autorizzato, la palla che dopo il rimbalzo '
        'esce dal perimetro o attraverso la porta fa perdere il punto.',
    keywords: ['fuori', 'uscire', 'porta', 'esterno', 'salida', 'recuperare'],
    source: '$_fip — Regola 16, Gioco esterno autorizzato',
    ruleRef: 'Regola 16; Regola 13.1(d); sezione Il campo, Zona di sicurezza',
  ),
  RuleEntry(
    id: 'smash_out',
    question: 'Se lo smash esce dal campo che succede?',
    answer:
        'Se la palla rimbalza correttamente nel campo avversario e poi esce '
        'oltre le pareti o attraverso la porta, il punto è di chi ha colpito, '
        'a meno che nei campi con gioco esterno autorizzato un avversario non '
        'la recuperi prima del secondo rimbalzo. Nel gioco esterno '
        'autorizzato, se la palla esce sopra la parete di fondo il punto è '
        'perso; se esce sopra la parete laterale o dalla porta, il punto si '
        'perde quando la palla rimbalza una seconda volta o tocca un elemento '
        'estraneo al campo.',
    keywords: ['smash', 'esce', 'per', 'tre', 'quattro', 'x3', 'x4', 'fuori'],
    source: '$_fip — Regole 13 e 15',
    ruleRef: 'Regola 13.1(d)-(e); Regola 15',
  ),
  RuleEntry(
    id: 'change_sides',
    question: 'Quando si cambia campo?',
    answer:
        'Si cambia campo alla fine del 1°, del 3° e di ogni game dispari del '
        'set. Di conseguenza alla fine di un set si cambia solo se il totale '
        'dei game giocati è dispari (per esempio 6-3 o 7-6): dopo un set '
        'pari come 6-0, 6-2 o 6-4 il cambio slitta alla fine del primo game '
        'del set successivo. Nel tie-break si cambia ogni 6 punti. Se per '
        'errore non si cambia, la correzione va fatta appena ci si accorge e '
        'i punti già giocati restano validi.',
    keywords: ['cambio', 'campo', 'lato', 'dispari', 'quando'],
    source: '$_fip — Regola 5, Cambi di campo',
    ruleRef: 'Regola 5, punti 1-3',
    example:
        'Set finito 6-4: nessun cambio campo, si cambia dopo il primo game '
        'del set dopo. Set finito 6-3: si cambia subito.',
  ),
  RuleEntry(
    id: 'ball_hits_player',
    question: 'Se la palla colpisce un giocatore?',
    answer:
        'Se dopo aver colpito la palla questa tocca te, il tuo compagno o '
        'qualcosa che indossate, il punto va agli avversari. Se la palla '
        'colpita dagli avversari tocca te o la tua racchetta prima di '
        'rimbalzare, il punto è loro; nella risposta al servizio, se la palla '
        'servita colpisce un giocatore in ricezione o la sua racchetta prima '
        'del rimbalzo, il punto è del battitore.',
    keywords: ['colpisce', 'giocatore', 'corpo', 'tocca', 'addosso'],
    source: '$_fip — Regole 13 e 8',
    ruleRef: 'Regola 13.1(j)-(k); Regola 8, punto 5',
  ),
  RuleEntry(
    id: 'double_hit',
    question: 'Si può colpire la palla due volte?',
    answer:
        'Il doppio contatto è consentito solo se avviene nello stesso '
        'movimento continuo e la traiettoria naturale della palla non cambia '
        'in modo sostanziale. Due colpi distinti fanno perdere il punto, così '
        'come il colpo dato da entrambi i compagni, in contemporanea o uno '
        'dopo l\'altro: la palla può essere giocata da un solo componente '
        'della coppia. Non è considerato doppio tocco il caso in cui due '
        'compagni provano a colpire insieme e uno prende la palla e l\'altro '
        'la racchetta del compagno.',
    keywords: ['doppio', 'tocco', 'due', 'volte', 'compagno'],
    source: '$_fip — Regole 13 e 14',
    ruleRef: 'Regola 13.1(i) e 13.1(o); Regola 14.1(h)',
  ),
  RuleEntry(
    id: 'let_point',
    question: 'Quando si ripete il punto (let)?',
    answer:
        'Il punto si ripete se la palla si rompe durante lo scambio, se un '
        'elemento estraneo al gioco invade il campo, in caso di interruzione '
        'per situazioni impreviste non dipendenti dai giocatori, oppure se la '
        'palla in gioco colpisce un oggetto a terra nel campo avversario (per '
        'esempio un\'altra palla) e questo si sposta in modo pericoloso o tale '
        'da interferire. Il let va chiesto subito: se si continua a giocare '
        'si perde il diritto di chiederlo, e se l\'arbitro giudica la '
        'richiesta non fondata il punto è perso.',
    keywords: ['let', 'ripetere', 'interferenza', 'palla', 'esterna'],
    source: '$_fip — Regola 10, Ripetizione o punto "let"',
    ruleRef: 'Regola 10.1(a)-(f)',
  ),
  RuleEntry(
    id: 'interference',
    question: 'Cosa succede se un avversario mi disturba durante il colpo?',
    answer:
        'C\'è interferenza quando un giocatore, con un\'azione deliberata o '
        'involontaria, disturba un avversario mentre esegue un colpo. Se '
        'l\'interferenza è deliberata il punto viene assegnato agli '
        'avversari; se è involontaria si chiama let e il punto si ripete. '
        'Alla seconda interferenza involontaria della stessa coppia, però, '
        'l\'arbitro assegna il punto agli avversari.',
    keywords: [
      'interferenza',
      'disturbo',
      'disturbare',
      'volontaria',
      'involontaria',
      'ostacolo',
    ],
    source: '$_fip — Regola 11, Interferenza',
    ruleRef: 'Regola 11',
  ),
  RuleEntry(
    id: 'safety_cord',
    question: 'Cosa succede se rompo il cordino o mi cade la racchetta?',
    answer:
        'Si perde immediatamente il punto in disputa. Il cordino di sicurezza '
        'è obbligatorio: è un laccio non elastico lungo al massimo 35 cm '
        'fissato al manico e va portato al polso come protezione contro gli '
        'incidenti. Se durante lo scambio il cordino si rompe o la racchetta '
        'sfugge di mano, la coppia perde il punto.',
    keywords: [
      'cordino',
      'laccetto',
      'laccio',
      'polso',
      'racchetta',
      'cade',
      'rompe',
    ],
    source: '$_fip — Regola 13 e sezione La racchetta da padel',
    ruleRef: 'Regola 13.1(r); La racchetta da padel, punto 9',
  ),
  RuleEntry(
    id: 'ball_change',
    question: 'Quando si cambiano le palle e cosa succede se si rompono?',
    answer:
        'Gli organizzatori devono annunciare in anticipo marca e tipo di '
        'palle, quante se ne usano (2 o 3) e l\'eventuale politica di cambio. '
        'Il cambio può avvenire dopo un numero dispari di game stabilito '
        '(il riscaldamento conta come due game e il tie-break come uno) '
        'oppure all\'inizio di un set; non si cambia mai all\'inizio di un '
        'tie-break, in quel caso si rinvia al secondo game del set '
        'successivo. Se una palla si perde o si danneggia va sostituita '
        'subito e non si gioca con una sola palla: entro i primi due game '
        'dopo un cambio si usa una palla nuova, dopo si usa una palla usata '
        'di usura simile.',
    keywords: [
      'palle',
      'palla',
      'cambio',
      'rotta',
      'sostituzione',
      'nuove',
      'persa',
    ],
    source: '$_fip — Regola 17, Cambio delle palle',
    ruleRef: 'Regola 17.1(a)-(e)',
  ),
  RuleEntry(
    id: 'court_size',
    question: 'Quanto è grande un campo da padel?',
    answer:
        'Il campo è un rettangolo di 10 m di larghezza per 20 m di lunghezza '
        '(misure interne, tolleranza 0,5%), diviso a metà dalla rete. Le '
        'linee di servizio sono a 6,95 m dalla rete e la linea centrale di '
        'servizio divide a metà quello spazio. I fondi sono alti 4 m in '
        'totale: 3 m di parete più 1 m di griglia metallica. La rete è alta '
        '88 cm al centro e 92 cm alle estremità. L\'altezza libera minima è '
        '6 m (8 m consigliati nei nuovi impianti).',
    keywords: ['campo', 'misure', 'dimensioni', 'metri', 'rete', 'altezza'],
    source: '$_fip — Il campo',
    ruleRef: 'Sezioni Dimensioni, Rete, Recinzioni e Fondi',
  ),
  RuleEntry(
    id: 'racket_ball',
    question: 'Che racchetta e palle si usano?',
    answer:
        'La racchetta ha superficie forata, lunghezza totale massima 45,5 cm, '
        'larghezza massima 26 cm e spessore massimo 38 mm, con cordino di '
        'sicurezza obbligatorio al polso (max 35 cm). Non può avere '
        'dispositivi visibili o sonori che comunichino, avvisino o diano '
        'istruzioni al giocatore durante il game. Le palle sono sfere di '
        'gomma di diametro tra 6,35 e 6,77 cm e peso tra 56,0 e 59,4 g, con '
        'rimbalzo tra 135 e 145 cm da 2,54 m di altezza e pressione interna '
        'tra 4,6 e 5,2 kg per 2,54 cm quadri.',
    keywords: ['racchetta', 'pala', 'palla', 'palle', 'cordino', 'laccetto'],
    source: '$_fip — La palla e La racchetta da padel',
    ruleRef: 'La palla, punti 1-3; La racchetta da padel, punti 3-4, 9-10',
  ),
  RuleEntry(
    id: 'warmup_time',
    question: 'Quanto dura il riscaldamento e le pause?',
    answer:
        'Il riscaldamento è un palleggio di cortesia obbligatorio di 3 '
        'minuti. Tra un punto e l\'altro sono concessi al massimo 20 secondi; '
        'ai cambi di campo al massimo 90 secondi; alla fine di ogni set al '
        'massimo 120 secondi. Dopo il primo game di ogni set e durante il '
        'tie-break il gioco è continuo e si cambia campo senza pausa; per il '
        'cambio nel tie-break il regolamento indica 20 secondi. Il tempo di '
        'riposo si conta dalla fine di un punto all\'inizio del successivo con '
        'il servizio. Chi non è pronto in campo 10 minuti dopo l\'orario '
        'ufficiale perde il match a tavolino, salvo cause di forza maggiore.',
    keywords: ['riscaldamento', 'pausa', 'tempo', 'secondi', 'durata'],
    source: '$_fip — Regola 2, Tempi',
    ruleRef: 'Regola 2, punti 1-7 e 10',
  ),
  RuleEntry(
    id: 'suspensions_medical',
    question: 'Come funzionano sospensioni, infortuni e assistenza medica?',
    answer:
        'Se il match viene sospeso e poi riprende, il riscaldamento dipende '
        'dalla durata: fino a 5 minuti nessun riscaldamento, da 5 a 20 minuti '
        '1 minuto, oltre 20 minuti 3 minuti. Si riprende esattamente dal '
        'punto in cui ci si era fermati, con lo stesso punteggio, lo stesso '
        'battitore, le stesse posizioni e lo stesso ordine di servizio e '
        'risposta; se la sospensione è per mancanza di luce il match va '
        'fermato con un numero pari di game. In caso di infortunio o '
        'condizione medica trattabile il giocatore ha diritto a un\'unica '
        'interruzione di 3 minuti per ciascuna condizione, ripetibile nei due '
        'cambi campo successivi ma dentro i tempi regolamentari. Per incidenti '
        'non dipendenti dal gioco (svenimento, reazione allergica, crisi '
        'respiratoria) l\'arbitro può concedere fino a 15 minuti; per '
        'circostanze inusuali come una caduta involontaria, fino a 5 minuti.',
    keywords: [
      'sospensione',
      'infortunio',
      'medico',
      'medica',
      'interruzione',
      'pioggia',
      'ripresa',
    ],
    source: '$_fip — Regola 2, Tempi',
    ruleRef: 'Regola 2, punti 11-17',
  ),
  RuleEntry(
    id: 'penalties',
    question: 'Quali sono le penalità per ritardi e comportamento scorretto?',
    answer:
        'Il gioco deve essere continuo: superare i tempi previsti dalla '
        'Regola 2 comporta prima un avvertimento, poi — alla ripetizione — la '
        'perdita del primo servizio se si sta servendo o di un punto se si è '
        'in risposta, quindi la perdita di punti successivi a giudizio '
        'dell\'arbitro e, nei casi gravi, penalità aggiuntive fino alla '
        'perdita di game o alla squalifica. Per le violazioni del codice '
        'disciplinare la scala è: primo caso avvertimento, secondo '
        'avvertimento con perdita del punto, terzo avvertimento con '
        'squalifica. Per gli allenatori: primo caso avvertimento, secondo '
        'espulsione dal match. In caso di aggressione fisica o verbale grave '
        'la squalifica è immediata.',
    keywords: [
      'penalità',
      'sanzione',
      'squalifica',
      'avvertimento',
      'ritardo',
      'condotta',
    ],
    source: '$_fip — Etichetta e norme di condotta',
    ruleRef: 'Gioco continuo e ritardi; Tabella delle penalità',
  ),
  RuleEntry(
    id: 'electronic_devices_tournaments',
    question: 'Posso usare smartwatch e app di punteggio in torneo?',
    answer:
        'Non darlo per scontato: avere l\'app o la companion installata non '
        'equivale all\'autorizzazione a usarla in competizione. Nei principali '
        'circuiti FIP 2026 un giocatore o un allenatore non può usare alcun '
        'dispositivo elettronico dall\'inizio dello scambio (nel rulebook '
        'Premier Padel: dal palleggio di riscaldamento) fino alla fine del '
        'match — comprese le pause per bagno, cambio d\'abbigliamento, '
        'time-out medico e interruzioni di gioco — salvo approvazione del '
        'Supervisor o del Referee del torneo; l\'uso è consentito quando il '
        'gioco è ufficialmente sospeso. Chi ha bisogno di un dispositivo per '
        'monitorarsi per motivi di salute deve chiedere il permesso al '
        'Supervisor. Il regolamento FIP vieta inoltre racchette con '
        'dispositivi visibili o sonori che comunichino o diano istruzioni '
        'durante il game. Prima di usare Padelandia in gara chiedi al giudice '
        'di gara: in caso di dubbio vale la sua decisione.',
    keywords: [
      'smartwatch',
      'orologio',
      'dispositivo',
      'elettronico',
      'torneo',
      'gara',
      'app',
      'consentito',
      'autorizzazione',
    ],
    source:
        'CUPRA FIP Tour Official Rulebook 2026 e Premier Padel Official '
        'Rulebook 2026; $_fip — La racchetta da padel',
    ruleRef:
        'Sezione 6.1.4(D) Electronic devices di entrambi i rulebook; '
        'La racchetta da padel, punto 10',
  ),
  RuleEntry(
    id: 'who_calls',
    question: 'Chi decide i punti dubbi senza arbitro?',
    answer:
        'Nelle partite amatoriali senza arbitro decide la coppia nel cui '
        'campo è rimbalzata la palla, in buona fede. In caso di disaccordo la '
        'prassi è ripetere il punto. Nei tornei ufficiali decide l\'arbitro, '
        'che è anche l\'unico a poter giudicare la fondatezza di un let.',
    keywords: ['arbitro', 'dubbio', 'decidere', 'chiamata', 'contestazione'],
    source: 'Prassi FIP / fair play — partite senza arbitro',
    ruleRef: null,
  ),
];
