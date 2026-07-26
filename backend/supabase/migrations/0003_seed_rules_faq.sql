-- Seed FAQ regolamento (generato da rally_core tool/generate_faq_seed.dart — non modificare a mano).

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'scoring_base',
  'Come si contano i punti nel padel?',
  'Come nel tennis: 15, 30, 40 e game. Sul 40-40 (parità) si gioca il vantaggio oppure il punto de oro (golden point) a seconda del formato. Un set si vince a 6 game con 2 di scarto; sul 6-6 si gioca il tie-break. La partita è di norma al meglio dei 3 set.',
  '{"punteggio","punti","contare","game","set","15","30","40"}',
  'FIP Rules of Padel — Punteggio',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'golden_point',
  'Come funziona il golden point (punto de oro)?',
  'Sul 40-40 si gioca un punto secco che assegna il game. La coppia in risposta sceglie da quale lato ricevere (destra o sinistra); il ricevitore scelto deve restare su quel lato per quel punto. Non ci sono vantaggi.',
  '{"golden","oro","punto","deuce","parità","40-40","lato"}',
  'FIP Rules of Padel — Regola sul punteggio (no-advantage)',
  'Siete 40-40: chi risponde sceglie il lato. Il punto successivo decide il game.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'tie_break',
  'Come si calcola il tie-break?',
  'Si gioca sul 6-6. Vince chi arriva per primo a 7 punti con almeno 2 di scarto (si prosegue a oltranza: 8-6, 9-7…). Il primo giocatore serve 1 punto, poi si alternano ogni 2 punti. Si cambia campo ogni 6 punti. Il set si registra 7-6.',
  '{"tie-break","tiebreak","tie","break","6-6","sette"}',
  'FIP Rules of Padel — Tie-break',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'super_tie_break',
  'Cos''è il super tie-break?',
  'In molti tornei amatoriali il terzo set è sostituito da un super tie-break a 10 punti con 2 di scarto. Chi lo vince conquista il set decisivo e la partita.',
  '{"super","tie-break","terzo","set","dieci","10"}',
  'Regolamenti di gara FIP — formati abbreviati',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'serve_how',
  'Come si batte il servizio?',
  'Il servizio è sempre sotto la cintura: la palla va fatta rimbalzare a terra dietro la linea di servizio e colpita all''altezza massima della vita. Il battitore deve avere almeno un piede a terra e non può toccare o superare la linea con i piedi. La battuta è in diagonale e la palla deve rimbalzare nel riquadro di servizio opposto.',
  '{"servizio","battuta","battere","servire","cintura","vita"}',
  'FIP Rules of Padel — Il servizio',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'serve_let',
  'Quando è let (net) al servizio?',
  'È let se la palla tocca la rete e poi rimbalza nel riquadro di servizio corretto, oppure se tocca la rete e poi il ricevitore o un oggetto prima del rimbalzo. Il servizio si ripete. Se dopo la rete la palla rimbalza correttamente e poi finisce nella griglia (rete metallica), il servizio è fallo.',
  '{"let","net","rete","servizio","ripetere","nastro"}',
  'FIP Rules of Padel — Let',
  'La battuta tocca il nastro e atterra nel riquadro giusto: si ripete. Tocca il nastro e finisce sulla griglia: fallo.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'serve_fault',
  'Quando il servizio è fallo?',
  'È fallo se: la palla non rimbalza nel riquadro diagonale opposto; rimbalza e poi tocca la griglia metallica prima del secondo rimbalzo (nel servizio la griglia è sempre fallo); il battitore calpesta o supera la linea; colpisce la palla sopra la vita; manca la palla al tentativo di colpirla. Come nel tennis ci sono due servizi a disposizione.',
  '{"fallo","servizio","griglia","doppio","errore","piede"}',
  'FIP Rules of Padel — Falli di servizio',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'walls_own_side',
  'La palla può toccare le pareti del mio campo?',
  'Sì: dopo il rimbalzo a terra la palla può colpire le pareti del tuo campo e resta in gioco. Puoi anche colpire la palla facendola passare sopra la rete dopo che è rimbalzata sulla tua parete. La palla NON può invece toccare direttamente la tua parete prima di superare la rete quando la colpisci: sarebbe punto perso.',
  '{"parete","pareti","vetro","muro","rimbalzo","sponda"}',
  'FIP Rules of Padel — Palla in gioco',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'grid',
  'La palla può toccare la griglia?',
  'Durante lo scambio: se la palla che arriva dal campo avversario tocca prima il terreno e poi la griglia, è regolare e il gioco continua. Se invece colpisce direttamente la griglia al volo prima di rimbalzare, il punto è dell''avversario. Nel servizio la griglia dopo il rimbalzo è comunque fallo.',
  '{"griglia","rete","metallica","metallo","recinzione"}',
  'FIP Rules of Padel — Palla in gioco / Punto perso',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'double_bounce',
  'Quando si perde il punto?',
  'Si perde il punto se: la palla rimbalza due volte nel proprio campo; si colpisce la palla al volo prima che superi la rete; la palla colpisce te o il tuo compagno; si tocca la rete con corpo o racchetta mentre la palla è in gioco; si colpisce la palla due volte; la palla colpita finisce direttamente sulla propria parete senza superare la rete.',
  '{"perdere","punto","doppio","rimbalzo","tocca","corpo"}',
  'FIP Rules of Padel — Punto perso',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'net_touch',
  'Posso toccare la rete?',
  'No. Se tu, la tua racchetta o qualsiasi cosa indossi tocca la rete, i pali o il campo avversario mentre la palla è in gioco, perdi il punto.',
  '{"toccare","rete","palo","invasione","contatto"}',
  'FIP Rules of Padel — Punto perso',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'over_net_reach',
  'Posso colpire la palla oltre la rete?',
  'In generale no: si colpisce la palla nel proprio campo. Eccezione: se la palla rimbalza nel tuo campo e torna indietro da sola verso il campo avversario (per effetto o vento), puoi invadere con la racchetta oltre la rete per colpirla, senza toccare rete o avversari. È inoltre consentito il "gancho" che accompagna la palla oltre la rete dopo averla colpita nel proprio spazio.',
  '{"oltre","rete","invadere","sopra","colpire","gancho"}',
  'FIP Rules of Padel — Invasione consentita',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'out_of_court',
  'Si può giocare la palla fuori dal campo?',
  'Sì, nei campi che lo consentono (porte aperte): se la palla supera le pareti ed esce, i giocatori possono uscire e rimandarla nel campo avversario prima del secondo rimbalzo. Il punto resta in gioco. Serve che il campo abbia gli spazi di uscita regolamentari.',
  '{"fuori","uscire","porta","esterno","salida","recuperare"}',
  'FIP Rules of Padel — Gioco esterno al campo',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'smash_out',
  'Se lo smash esce dal campo che succede?',
  'Se la palla rimbalza nel campo avversario e poi esce oltre le pareti (per 3 o per 4), il punto è di chi ha colpito, a meno che un avversario non la recuperi prima del secondo rimbalzo nei campi con uscita consentita.',
  '{"smash","esce","per","tre","quattro","x3","x4","fuori"}',
  'FIP Rules of Padel — Punto vinto',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'change_sides',
  'Quando si cambia campo?',
  'Si cambia campo quando la somma dei game del set è dispari (1°, 3°, 5° game…). Nel tie-break si cambia ogni 6 punti. Tra un set e l''altro c''è la pausa e si riparte dal lato opposto.',
  '{"cambio","campo","lato","dispari","quando"}',
  'FIP Rules of Padel — Cambio di campo',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'serve_order',
  'Chi serve e in che ordine?',
  'Le coppie si alternano al servizio ogni game. All''inizio del set ogni coppia decide quale dei due giocatori serve per primo; l''ordine interno si mantiene per tutto il set e può cambiare solo al set successivo. Nel tie-break si segue la rotazione 1-2-2-2…',
  '{"ordine","servizio","chi","serve","turno","rotazione"}',
  'FIP Rules of Padel — Ordine di servizio',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'receive_position',
  'Il ricevitore può stare dove vuole?',
  'Il ricevitore deve trovarsi nel riquadro diagonale al battitore e la palla deve rimbalzare nel suo riquadro. Il compagno del ricevitore e il compagno del battitore possono posizionarsi ovunque nel proprio campo.',
  '{"ricevitore","risposta","posizione","riquadro","diagonale"}',
  'FIP Rules of Padel — La risposta',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'ball_hits_player',
  'Se la palla colpisce un giocatore?',
  'Se la palla in gioco tocca un giocatore o qualsiasi cosa indossi o porti (racchetta esclusa nel colpo regolare), il punto va agli avversari, anche se il giocatore è fuori dal campo.',
  '{"colpisce","giocatore","corpo","tocca","addosso"}',
  'FIP Rules of Padel — Punto perso',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'double_hit',
  'Si può colpire la palla due volte?',
  'Il doppio tocco involontario nello stesso movimento continuo è consentito (palla "accompagnata" nello stesso gesto). Due colpi distinti o un tocco di entrambi i compagni fanno perdere il punto.',
  '{"doppio","tocco","due","volte","compagno"}',
  'FIP Rules of Padel — Colpo corretto',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'let_point',
  'Quando si ripete il punto (let)?',
  'Il punto si ripete se un elemento esterno entra in campo o interferisce col gioco (palla da un altro campo, oggetto, interruzione), o in caso di dubbio arbitrale. Sul let di servizio si ripete solo quel servizio.',
  '{"let","ripetere","interferenza","palla","esterna"}',
  'FIP Rules of Padel — Let',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'court_size',
  'Quanto è grande un campo da padel?',
  'Il campo misura 20 m × 10 m, diviso a metà dalla rete. Le pareti di fondo sono alte 3 m più 1 m di griglia (4 m totali); le pareti laterali seguono il profilo regolamentare 3-2 m. La rete è alta 88 cm al centro e 92 cm ai lati.',
  '{"campo","misure","dimensioni","metri","rete","altezza"}',
  'FIP Rules of Padel — Il campo',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'racket_ball',
  'Che racchetta e palle si usano?',
  'La racchetta da padel ha superficie forata, lunghezza massima 45,5 cm e spessore massimo 38 mm, con cordino di sicurezza al polso (obbligatorio). Le palle sono simili a quelle da tennis ma con pressione leggermente inferiore.',
  '{"racchetta","pala","palla","palle","cordino","laccetto"}',
  'FIP Rules of Padel — Attrezzatura',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'warmup_time',
  'Quanto dura il riscaldamento e le pause?',
  'Riscaldamento massimo 5 minuti. Tra i punti massimo 20 secondi, ai cambi di campo 90 secondi, tra i set 120 secondi. Nel tie-break i cambi campo sono senza pausa.',
  '{"riscaldamento","pausa","tempo","secondi","durata"}',
  'FIP Rules of Padel — Gioco continuo',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'smash_return_own_side',
  'Posso rimandare la palla sulla mia parete per farla passare?',
  'No: se colpisci la palla e questa tocca la tua parete prima di superare la rete, perdi il punto. La palla colpita deve superare direttamente la rete (o al limite toccare il nastro).',
  '{"mia","parete","sponda","passare","indietro","boomerang"}',
  'FIP Rules of Padel — Punto perso',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (
  'who_calls',
  'Chi decide i punti dubbi senza arbitro?',
  'Nelle partite amatoriali senza arbitro decide la coppia nel cui campo è rimbalzata la palla, in buona fede. In caso di disaccordo la prassi è ripetere il punto. Nei tornei ufficiali decide l''arbitro.',
  '{"arbitro","dubbio","decidere","chiamata","contestazione"}',
  'Prassi FIP / fair play — partite senza arbitro',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  example = excluded.example, updated_at = now();


