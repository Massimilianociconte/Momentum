-- Allinea regole e knowledge base alla FIP Rules of Padel, revisione di
-- applicazione 01.01.2026 (adottata ad Acapulco il 28.11.2025).
--
-- Perché serve una migration forward: 0003_seed_rules_faq.sql e
-- 0007_padel_knowledge_base.sql sono già applicate e non vanno riscritte.
-- Correzioni portate qui:
--   * risposta contro la propria parete: era data per errata, la Regola 14.1(b)
--     la considera una risposta corretta;
--   * posizione del ricevitore: la Regola 3.2 lascia libera la posizione, è la
--     palla servita a dover rimbalzare nel riquadro diagonale;
--   * riscaldamento: la Regola 2.2 prevede 3 minuti, non 5;
--   * cambio campo di fine set solo con totale game dispari (Regola 5.1);
--   * Star Point (Regola 1, Opzione 2) assente dalla knowledge base cloud e
--     dalle FAQ v2, pur essendo supportato dall'app;
--   * formati alternativi mancanti: mini-set a 4, tie-break decisivo a 7,
--     terzo set senza tie-break;
--   * avvertenza sull'uso dei dispositivi elettronici in torneo.
--
-- rules_faq guadagna rule_ref e rules_version, così ogni risposta cita numero
-- di regola ed edizione; l'edge function assistant usa quei valori sia nel
-- prompt sia come parte della chiave di cache.
begin;

-- ---------------------------------------------------------------- rules_faq

alter table public.rules_faq
  add column if not exists rule_ref text;

alter table public.rules_faq
  add column if not exists rules_version text not null default '2026.1';

comment on column public.rules_faq.rule_ref is
  'Riferimento puntuale alla regola dentro source, es. "Regola 14.1(b)".';
comment on column public.rules_faq.rules_version is
  'Edizione del regolamento a cui la risposta è allineata (padelRulesVersion).';

-- Seed FAQ regolamento (generato da rally_core tool/generate_faq_seed.dart — non modificare a mano).
-- Edizione: FIP Rules of Padel — revisione di applicazione 01.01.2026 (versione 2026.1).

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'scoring_base',
  'Come si contano i punti nel padel?',
  'Come nel tennis: 15, 30, 40 e game. Sul 40-40 (parità) si gioca il vantaggio, lo Star Point oppure il punto de oro (Golden Point) a seconda dell''opzione scelta prima del match. Un set si vince a 6 game con almeno 2 di scarto; sul 5-5 si gioca fino al 7-5 e sul 6-6 si gioca il tie-break. La partita è di norma al meglio dei 3 set.',
  '{"punteggio","punti","contare","game","set","15","30","40"}',
  'FIP Rules of Padel — Regola 1, Punteggio in un game',
  'Regola 1, opzioni 1-3 e punti 2-3',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'star_point',
  'Come funziona lo Star Point FIP?',
  'È l''opzione 2 della Regola 1. Sul primo 40-40 si chiama parità 1: il punto seguente assegna vantaggio 1. Se chi è in vantaggio perde il punto si torna a parità 2; seguono allo stesso modo vantaggio 2 e, se viene annullato, parità 3. A parità 3 si gioca lo Star Point: la coppia in risposta sceglie se ricevere da destra o da sinistra, ma i due giocatori NON possono scambiarsi le posizioni per ricevere il punto decisivo. Chi vince lo Star Point vince il game. Nel misto il punto decisivo lo riceve una persona dello stesso sesso di chi serve.',
  '{"star","star point","parità 1","parità 2","parità 3","deuce 1","deuce 2","deuce 3","vantaggio 1","vantaggio 2","decisivo"}',
  'FIP Rules of Padel — Regola 1, Opzione 2: Star Point',
  'Regola 1, Opzione 2, punti 1-2',
  '2026.1',
  'Parità 1, vantaggio 1, parità 2, vantaggio 2, parità 3: il punto successivo è lo Star Point e decide il game.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'golden_point',
  'Come funziona il golden point (punto de oro)?',
  'È l''opzione 3 della Regola 1, il punteggio "senza vantaggi". Si contano 15, 30, 40 e game; se entrambe le coppie arrivano a tre punti si chiama parità e si gioca un unico punto decisivo che assegna il game. La coppia in risposta sceglie se ricevere da destra o da sinistra, ma i due giocatori NON possono scambiarsi le posizioni per ricevere il punto decisivo. Nel misto il punto decisivo lo riceve una persona dello stesso sesso di chi serve. A differenza dello Star Point non esiste alcun ciclo di vantaggi: si decide subito al primo 40-40.',
  '{"golden","oro","punto","deuce","parità","40-40","lato"}',
  'FIP Rules of Padel — Regola 1, Opzione 3: Golden Point',
  'Regola 1, Opzione 3, punti 1-3',
  '2026.1',
  'Siete 40-40: chi risponde sceglie il lato senza cambiare posizione col compagno. Il punto successivo decide il game.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'tie_break',
  'Come si calcola il tie-break?',
  'Si gioca sul 6-6. Vince chi arriva per primo a 7 punti con almeno 2 di scarto (si prosegue a oltranza: 8-6, 9-7…). Inizia a servire chi aveva il turno secondo l''ordine del set e serve un solo punto, da destra; poi si alternano due punti a testa, iniziando da sinistra. Si cambia campo ogni 6 punti. Il set si registra 7-6 e il set successivo lo inizia al servizio il giocatore della coppia che non aveva iniziato a servire il tie-break.',
  '{"tie-break","tiebreak","tie","break","6-6","sette"}',
  'FIP Rules of Padel — Regola 1, Tie-break',
  'Regola 1, Tie-break, punti 1-5',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'super_tie_break',
  'Cos''è il super tie-break?',
  'È uno dei metodi di punteggio alternativi previsti dalla Regola 1: sul risultato di un set pari, al posto dell''ultimo set si gioca un super tie-break a 10 punti con almeno 2 di scarto. Chi lo vince vince il match. Va stabilito prima dell''inizio della partita.',
  '{"super","tie-break","terzo","set","dieci","10"}',
  'FIP Rules of Padel — Regola 1, Metodi di punteggio alternativi',
  'Regola 1, Metodi alternativi, punto 1(c)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'mini_set',
  'Cos''è il mini-set a 4 game?',
  'È un metodo di punteggio alternativo previsto dalla Regola 1: il set si vince a 4 game con almeno 2 di scarto. Se le due coppie arrivano a 4 game pari si gioca il tie-break. Serve per accorciare la durata delle partite e va stabilito prima dell''inizio del match.',
  '{"mini","mini-set","quattro","4","game","set","corto","breve"}',
  'FIP Rules of Padel — Regola 1, Metodi di punteggio alternativi',
  'Regola 1, Metodi alternativi, punto 1(a)',
  '2026.1',
  'Sul 4-4 si gioca il tie-break; il mini-set si chiude 5-4.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'match_tie_break_7',
  'Cos''è il tie-break decisivo a 7 punti?',
  'È un metodo di punteggio alternativo previsto dalla Regola 1: sul risultato di un set pari, al posto dell''ultimo set si gioca un tie-break a 7 punti con almeno 2 di scarto, che è definitivo e decide il match. È la versione breve del super tie-break a 10 e va stabilito prima dell''inizio della partita.',
  '{"tie-break","decisivo","sette","7","match","ultimo","set"}',
  'FIP Rules of Padel — Regola 1, Metodi di punteggio alternativi',
  'Regola 1, Metodi alternativi, punto 1(b)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'third_set_no_tiebreak',
  'Si può giocare il terzo set senza tie-break?',
  'Sì, se stabilito in anticipo. La Regola 1 prevede che, sul risultato di un set pari, il terzo set possa essere giocato senza tie-break: in quel caso sul 6-6 si continua finché una coppia non prende 2 game di vantaggio (7-5 nei game successivi, 8-6, 9-7…). Non è il comportamento predefinito: senza accordo preventivo sul 6-6 si gioca il tie-break.',
  '{"terzo","set","senza","tie-break","vantaggi","oltranza","advantage"}',
  'FIP Rules of Padel — Regola 1, Opzione 1: Vantaggi',
  'Regola 1, Opzione 1, punto 4',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'serve_how',
  'Come si batte il servizio?',
  'Il battitore deve stare con almeno un piede dietro la linea di servizio, tra il prolungamento immaginario della linea centrale e la parete laterale, e restarci finché la palla non è stata servita. Deve far rimbalzare la palla a terra nel proprio riquadro: la palla non può superare la linea di servizio (né la linea centrale immaginaria) prima di essere colpita. Il colpo va dato all''altezza della vita o sotto, con almeno un piede a contatto col terreno. La battuta è in diagonale e la palla deve rimbalzare nel riquadro di ricezione opposto: si inizia servendo verso il riquadro alla sinistra del ricevente e poi si alterna.',
  '{"servizio","battuta","battere","servire","cintura","vita"}',
  'FIP Rules of Padel — Regola 6, Il servizio',
  'Regola 6, punti 1-5',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'serve_let',
  'Quando è let (net) al servizio?',
  'Il servizio è "net" se la palla tocca la rete o i pali e poi atterra nel riquadro di ricezione corretto, purché non tocchi la griglia metallica prima del secondo rimbalzo, oppure se dopo aver toccato rete o pali colpisce un giocatore o un oggetto indossato o portato. Il servizio si ripete anche se la palla è servita quando il ricevitore non era pronto. Attenzione alla differenza tra i due servizi: se il let capita sul primo servizio si ripete il punto completo e il battitore ha di nuovo due servizi; se capita sul secondo si ripete solo il secondo servizio.',
  '{"let","net","rete","servizio","ripetere","nastro"}',
  'FIP Rules of Padel — Regola 9, Ripetizione o "let" e servizio "net"',
  'Regola 9, punti 1-2',
  '2026.1',
  'Let sul primo servizio: due servizi nuovi. Let sul secondo: si ripete solo il secondo.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'serve_fault',
  'Quando il servizio è fallo?',
  'È fallo se: il battitore viola una delle prescrizioni sul servizio (posizione dei piedi, rimbalzo nel proprio riquadro, colpo sopra la vita); manca la palla nel tentativo di colpirla; la palla rimbalza fuori dal riquadro di ricezione (le righe sono buone); la palla colpisce il battitore, il suo compagno o un oggetto da loro indossato o portato; la palla rimbalza nel riquadro e poi tocca la griglia metallica prima del secondo rimbalzo; la palla rimbalza nel riquadro ed esce direttamente dalle porte di un campo senza zona di sicurezza e quindi senza gioco esterno autorizzato. Ci sono due servizi a disposizione e due falli consecutivi fanno perdere il punto.',
  '{"fallo","servizio","griglia","doppio","errore","piede"}',
  'FIP Rules of Padel — Regola 7, Fallo di servizio',
  'Regola 7, punto 1(a)-(f); Regola 13.1(q)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'serve_order',
  'Chi serve e in che ordine? Cosa succede se sbaglio turno?',
  'Le coppie si alternano al servizio ogni game. Prima di ogni set ogni coppia decide quale dei due giocatori serve per primo; stabilito l''ordine non si può cambiare fino all''inizio del set successivo. Se un giocatore serve fuori turno, appena ci si accorge dell''errore deve servire chi avrebbe dovuto farlo: i punti giocati restano validi e un eventuale fallo di primo servizio non si conta. Se il game è già finito quando l''errore viene scoperto, l''ordine sbagliato resta fino alla fine del set. Se il servizio è battuto per distrazione dal lato sbagliato, si corregge appena ci si accorge: i punti restano validi e il fallo di primo servizio va invece conteggiato.',
  '{"ordine","servizio","chi","serve","turno","rotazione"}',
  'FIP Rules of Padel — Regola 6, Il servizio',
  'Regola 6, punti 7-9',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'receive_order',
  'In che ordine si riceve e cosa succede se si sbaglia?',
  'Nel primo game di ogni set la coppia in risposta decide chi riceve per primo: quel giocatore riceverà il primo servizio di ogni game fino alla fine del set. Durante il game i due compagni ricevono a turno alternato e l''ordine, una volta stabilito, non può essere cambiato per quel set o tie-break, ma può cambiare all''inizio di un set nuovo. Se durante un game o un tie-break l''ordine di ricezione viene alterato, si continua così fino alla fine di quel game o tie-break; dal game successivo si torna alle posizioni scelte inizialmente.',
  '{"ordine","ricezione","ricevere","risposta","turno","errore","correzione"}',
  'FIP Rules of Padel — Regola 8, Risposta al servizio',
  'Regola 8, punti 2-4',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'receive_position',
  'Il ricevitore può stare dove vuole?',
  'Sì. Il ricevitore può stare in qualsiasi punto del proprio campo, come il suo compagno e il compagno del battitore: nessuno è obbligato a posizionarsi dentro un riquadro. Riceve il giocatore che si trova diagonalmente di fronte al battitore, ed è la palla servita a dover rimbalzare nel riquadro di ricezione in diagonale. Il ricevitore deve aspettare che la palla rimbalzi nel proprio riquadro e colpirla prima del secondo rimbalzo. Unica eccezione: sul punto decisivo di Star Point e Golden Point i due giocatori in risposta non possono scambiarsi le posizioni.',
  '{"ricevitore","risposta","posizione","riquadro","diagonale"}',
  'FIP Rules of Padel — Regola 3, Posizione dei giocatori',
  'Regola 3, punti 1-2; Regola 8, punto 1',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'walls_own_side',
  'La palla può toccare le pareti del mio campo?',
  'Sì, in due modi diversi. Dopo che la palla è rimbalzata a terra nel tuo campo puoi lasciarla andare sulle tue pareti e giocarla dopo il rimbalzo sul vetro. Ed è una risposta valida anche colpire la palla contro una parete del tuo campo per farla passare di là: la Regola 14 considera corretta la risposta in cui la palla, dopo essere stata colpita, tocca prima la parete del proprio campo e poi rimbalza nel campo avversario. I limiti sono altri: la palla che colpisci non può toccare la griglia metallica o il terreno del tuo campo, e non può finire direttamente sulle pareti o sulla griglia avversarie senza rimbalzare prima nel campo avversario.',
  '{"parete","pareti","vetro","muro","rimbalzo","sponda"}',
  'FIP Rules of Padel — Regola 14, Risposta corretta',
  'Regola 14.1(b); limiti in Regola 13.1(g) e 13.1(l)',
  '2026.1',
  'Sei schiacciato in fondo: colpisci la palla contro il tuo vetro e quella scavalca la rete rimbalzando di là. Punto regolare.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'smash_return_own_side',
  'Posso rimandare la palla sulla mia parete per farla passare?',
  'Sì: è espressamente una risposta corretta. Puoi colpire la palla contro la parete del tuo campo purché poi rimbalzi nel campo avversario. Perdi invece il punto se la palla che hai colpito tocca la griglia metallica del tuo campo, il terreno del tuo campo o un oggetto estraneo appoggiato per terra dalla tua parte, e se dalla tua parete finisce direttamente sulle pareti o sulla griglia avversarie senza rimbalzare prima nel campo avversario.',
  '{"mia","parete","sponda","passare","indietro","boomerang"}',
  'FIP Rules of Padel — Regola 14, Risposta corretta',
  'Regola 14.1(b); Regola 13.1(g) e 13.1(l)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'grid',
  'La palla può toccare la griglia?',
  'Dipende da chi la manda. Se la palla arriva dal campo avversario, rimbalza prima a terra nel tuo campo e poi tocca la griglia (o una parete), resta in gioco e va rigiocata prima del secondo rimbalzo. Se invece sei tu a colpire la palla e questa finisce sulla griglia del tuo campo, perdi il punto. Nel servizio, la palla che rimbalza nel riquadro e poi tocca la griglia prima del secondo rimbalzo è fallo.',
  '{"griglia","rete","metallica","metallo","recinzione"}',
  'FIP Rules of Padel — Regole 12, 13 e 7',
  'Regola 12, punti 3-4; Regola 13.1(l); Regola 7.1(e)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'double_bounce',
  'Quando si perde il punto?',
  'Si perde il punto, tra gli altri casi, se: la palla rimbalza due volte prima di essere rinviata; si colpisce la palla prima che abbia superato la rete; tu, la tua racchetta o qualcosa che indossi toccate la rete, i pali, il cavo di tensione o il campo avversario mentre la palla è in gioco; la palla dopo che l''hai colpita tocca te o il tuo compagno; colpisci la palla due volte; la palla che hai colpito tocca la griglia metallica o il terreno del tuo campo; colpite la palla in due contemporaneamente o uno dopo l''altro; si salta oltre la rete mentre il punto è in gioco; si commettono due falli di servizio consecutivi; si rompe il cordino di sicurezza o si lascia cadere la racchetta.',
  '{"perdere","punto","doppio","rimbalzo","tocca","corpo"}',
  'FIP Rules of Padel — Regola 13, Punto perso',
  'Regola 13.1(a)-(r)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'net_touch',
  'Posso toccare la rete?',
  'No. Se tu, la tua racchetta o qualsiasi cosa indossi o porti tocca la rete, i pali, il cavo di tensione o una qualsiasi parte del campo avversario mentre la palla è in gioco, perdi il punto. Nel gioco esterno autorizzato il palo verticale che divide le porte è considerato zona neutra sopra 0,92 m: lì i giocatori possono toccarlo o aggrapparsi.',
  '{"toccare","rete","palo","invasione","contatto"}',
  'FIP Rules of Padel — Regola 13, Punto perso',
  'Regola 13.1(a)-(b)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'over_net_reach',
  'Posso colpire la palla oltre la rete?',
  'In generale no: si colpisce la palla nel proprio campo. Eccezione prevista dalla Regola 14: se la palla rimbalza correttamente nel campo avversario e per effetto o vento torna indietro verso il campo di chi ha servito il colpo, l''avversario può giocarla, purché né lui né i suoi indumenti o la racchetta tocchino la rete, i pali o il campo avversario. È inoltre considerata corretta la risposta con doppio contatto nello stesso movimento continuo, se la traiettoria naturale della palla non cambia in modo sostanziale.',
  '{"oltre","rete","invadere","sopra","colpire","gancho"}',
  'FIP Rules of Padel — Regola 14, Risposta corretta',
  'Regola 14.1(g)-(h)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'out_of_court',
  'Si può giocare la palla fuori dal campo?',
  'Solo nei campi autorizzati. La Regola 16 consente di uscire dal campo per giocare la palla soltanto se l''impianto rispetta le condizioni previste per zona di sicurezza e gioco esterno: due accessi per lato, nessun ostacolo in un''area di almeno 3 metri di larghezza (4 raccomandati) e 4 di lunghezza, alta almeno 3 metri. Anche i pali della luce devono stare fuori da quest''area: se ricadono nella zona di sicurezza il gioco esterno non è ammesso. Nei campi senza gioco esterno autorizzato, la palla che dopo il rimbalzo esce dal perimetro o attraverso la porta fa perdere il punto.',
  '{"fuori","uscire","porta","esterno","salida","recuperare"}',
  'FIP Rules of Padel — Regola 16, Gioco esterno autorizzato',
  'Regola 16; Regola 13.1(d); sezione Il campo, Zona di sicurezza',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'smash_out',
  'Se lo smash esce dal campo che succede?',
  'Se la palla rimbalza correttamente nel campo avversario e poi esce oltre le pareti o attraverso la porta, il punto è di chi ha colpito, a meno che nei campi con gioco esterno autorizzato un avversario non la recuperi prima del secondo rimbalzo. Nel gioco esterno autorizzato, se la palla esce sopra la parete di fondo il punto è perso; se esce sopra la parete laterale o dalla porta, il punto si perde quando la palla rimbalza una seconda volta o tocca un elemento estraneo al campo.',
  '{"smash","esce","per","tre","quattro","x3","x4","fuori"}',
  'FIP Rules of Padel — Regole 13 e 15',
  'Regola 13.1(d)-(e); Regola 15',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'change_sides',
  'Quando si cambia campo?',
  'Si cambia campo alla fine del 1°, del 3° e di ogni game dispari del set. Di conseguenza alla fine di un set si cambia solo se il totale dei game giocati è dispari (per esempio 6-3 o 7-6): dopo un set pari come 6-0, 6-2 o 6-4 il cambio slitta alla fine del primo game del set successivo. Nel tie-break si cambia ogni 6 punti. Se per errore non si cambia, la correzione va fatta appena ci si accorge e i punti già giocati restano validi.',
  '{"cambio","campo","lato","dispari","quando"}',
  'FIP Rules of Padel — Regola 5, Cambi di campo',
  'Regola 5, punti 1-3',
  '2026.1',
  'Set finito 6-4: nessun cambio campo, si cambia dopo il primo game del set dopo. Set finito 6-3: si cambia subito.',
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'ball_hits_player',
  'Se la palla colpisce un giocatore?',
  'Se dopo aver colpito la palla questa tocca te, il tuo compagno o qualcosa che indossate, il punto va agli avversari. Se la palla colpita dagli avversari tocca te o la tua racchetta prima di rimbalzare, il punto è loro; nella risposta al servizio, se la palla servita colpisce un giocatore in ricezione o la sua racchetta prima del rimbalzo, il punto è del battitore.',
  '{"colpisce","giocatore","corpo","tocca","addosso"}',
  'FIP Rules of Padel — Regole 13 e 8',
  'Regola 13.1(j)-(k); Regola 8, punto 5',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'double_hit',
  'Si può colpire la palla due volte?',
  'Il doppio contatto è consentito solo se avviene nello stesso movimento continuo e la traiettoria naturale della palla non cambia in modo sostanziale. Due colpi distinti fanno perdere il punto, così come il colpo dato da entrambi i compagni, in contemporanea o uno dopo l''altro: la palla può essere giocata da un solo componente della coppia. Non è considerato doppio tocco il caso in cui due compagni provano a colpire insieme e uno prende la palla e l''altro la racchetta del compagno.',
  '{"doppio","tocco","due","volte","compagno"}',
  'FIP Rules of Padel — Regole 13 e 14',
  'Regola 13.1(i) e 13.1(o); Regola 14.1(h)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'let_point',
  'Quando si ripete il punto (let)?',
  'Il punto si ripete se la palla si rompe durante lo scambio, se un elemento estraneo al gioco invade il campo, in caso di interruzione per situazioni impreviste non dipendenti dai giocatori, oppure se la palla in gioco colpisce un oggetto a terra nel campo avversario (per esempio un''altra palla) e questo si sposta in modo pericoloso o tale da interferire. Il let va chiesto subito: se si continua a giocare si perde il diritto di chiederlo, e se l''arbitro giudica la richiesta non fondata il punto è perso.',
  '{"let","ripetere","interferenza","palla","esterna"}',
  'FIP Rules of Padel — Regola 10, Ripetizione o punto "let"',
  'Regola 10.1(a)-(f)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'interference',
  'Cosa succede se un avversario mi disturba durante il colpo?',
  'C''è interferenza quando un giocatore, con un''azione deliberata o involontaria, disturba un avversario mentre esegue un colpo. Se l''interferenza è deliberata il punto viene assegnato agli avversari; se è involontaria si chiama let e il punto si ripete. Alla seconda interferenza involontaria della stessa coppia, però, l''arbitro assegna il punto agli avversari.',
  '{"interferenza","disturbo","disturbare","volontaria","involontaria","ostacolo"}',
  'FIP Rules of Padel — Regola 11, Interferenza',
  'Regola 11',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'safety_cord',
  'Cosa succede se rompo il cordino o mi cade la racchetta?',
  'Si perde immediatamente il punto in disputa. Il cordino di sicurezza è obbligatorio: è un laccio non elastico lungo al massimo 35 cm fissato al manico e va portato al polso come protezione contro gli incidenti. Se durante lo scambio il cordino si rompe o la racchetta sfugge di mano, la coppia perde il punto.',
  '{"cordino","laccetto","laccio","polso","racchetta","cade","rompe"}',
  'FIP Rules of Padel — Regola 13 e sezione La racchetta da padel',
  'Regola 13.1(r); La racchetta da padel, punto 9',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'ball_change',
  'Quando si cambiano le palle e cosa succede se si rompono?',
  'Gli organizzatori devono annunciare in anticipo marca e tipo di palle, quante se ne usano (2 o 3) e l''eventuale politica di cambio. Il cambio può avvenire dopo un numero dispari di game stabilito (il riscaldamento conta come due game e il tie-break come uno) oppure all''inizio di un set; non si cambia mai all''inizio di un tie-break, in quel caso si rinvia al secondo game del set successivo. Se una palla si perde o si danneggia va sostituita subito e non si gioca con una sola palla: entro i primi due game dopo un cambio si usa una palla nuova, dopo si usa una palla usata di usura simile.',
  '{"palle","palla","cambio","rotta","sostituzione","nuove","persa"}',
  'FIP Rules of Padel — Regola 17, Cambio delle palle',
  'Regola 17.1(a)-(e)',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'court_size',
  'Quanto è grande un campo da padel?',
  'Il campo è un rettangolo di 10 m di larghezza per 20 m di lunghezza (misure interne, tolleranza 0,5%), diviso a metà dalla rete. Le linee di servizio sono a 6,95 m dalla rete e la linea centrale di servizio divide a metà quello spazio. I fondi sono alti 4 m in totale: 3 m di parete più 1 m di griglia metallica. La rete è alta 88 cm al centro e 92 cm alle estremità. L''altezza libera minima è 6 m (8 m consigliati nei nuovi impianti).',
  '{"campo","misure","dimensioni","metri","rete","altezza"}',
  'FIP Rules of Padel — Il campo',
  'Sezioni Dimensioni, Rete, Recinzioni e Fondi',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'racket_ball',
  'Che racchetta e palle si usano?',
  'La racchetta ha superficie forata, lunghezza totale massima 45,5 cm, larghezza massima 26 cm e spessore massimo 38 mm, con cordino di sicurezza obbligatorio al polso (max 35 cm). Non può avere dispositivi visibili o sonori che comunichino, avvisino o diano istruzioni al giocatore durante il game. Le palle sono sfere di gomma di diametro tra 6,35 e 6,77 cm e peso tra 56,0 e 59,4 g, con rimbalzo tra 135 e 145 cm da 2,54 m di altezza e pressione interna tra 4,6 e 5,2 kg per 2,54 cm quadri.',
  '{"racchetta","pala","palla","palle","cordino","laccetto"}',
  'FIP Rules of Padel — La palla e La racchetta da padel',
  'La palla, punti 1-3; La racchetta da padel, punti 3-4, 9-10',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'warmup_time',
  'Quanto dura il riscaldamento e le pause?',
  'Il riscaldamento è un palleggio di cortesia obbligatorio di 3 minuti. Tra un punto e l''altro sono concessi al massimo 20 secondi; ai cambi di campo al massimo 90 secondi; alla fine di ogni set al massimo 120 secondi. Dopo il primo game di ogni set e durante il tie-break il gioco è continuo e si cambia campo senza pausa; per il cambio nel tie-break il regolamento indica 20 secondi. Il tempo di riposo si conta dalla fine di un punto all''inizio del successivo con il servizio. Chi non è pronto in campo 10 minuti dopo l''orario ufficiale perde il match a tavolino, salvo cause di forza maggiore.',
  '{"riscaldamento","pausa","tempo","secondi","durata"}',
  'FIP Rules of Padel — Regola 2, Tempi',
  'Regola 2, punti 1-7 e 10',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'suspensions_medical',
  'Come funzionano sospensioni, infortuni e assistenza medica?',
  'Se il match viene sospeso e poi riprende, il riscaldamento dipende dalla durata: fino a 5 minuti nessun riscaldamento, da 5 a 20 minuti 1 minuto, oltre 20 minuti 3 minuti. Si riprende esattamente dal punto in cui ci si era fermati, con lo stesso punteggio, lo stesso battitore, le stesse posizioni e lo stesso ordine di servizio e risposta; se la sospensione è per mancanza di luce il match va fermato con un numero pari di game. In caso di infortunio o condizione medica trattabile il giocatore ha diritto a un''unica interruzione di 3 minuti per ciascuna condizione, ripetibile nei due cambi campo successivi ma dentro i tempi regolamentari. Per incidenti non dipendenti dal gioco (svenimento, reazione allergica, crisi respiratoria) l''arbitro può concedere fino a 15 minuti; per circostanze inusuali come una caduta involontaria, fino a 5 minuti.',
  '{"sospensione","infortunio","medico","medica","interruzione","pioggia","ripresa"}',
  'FIP Rules of Padel — Regola 2, Tempi',
  'Regola 2, punti 11-17',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'penalties',
  'Quali sono le penalità per ritardi e comportamento scorretto?',
  'Il gioco deve essere continuo: superare i tempi previsti dalla Regola 2 comporta prima un avvertimento, poi — alla ripetizione — la perdita del primo servizio se si sta servendo o di un punto se si è in risposta, quindi la perdita di punti successivi a giudizio dell''arbitro e, nei casi gravi, penalità aggiuntive fino alla perdita di game o alla squalifica. Per le violazioni del codice disciplinare la scala è: primo caso avvertimento, secondo avvertimento con perdita del punto, terzo avvertimento con squalifica. Per gli allenatori: primo caso avvertimento, secondo espulsione dal match. In caso di aggressione fisica o verbale grave la squalifica è immediata.',
  '{"penalità","sanzione","squalifica","avvertimento","ritardo","condotta"}',
  'FIP Rules of Padel — Etichetta e norme di condotta',
  'Gioco continuo e ritardi; Tabella delle penalità',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'electronic_devices_tournaments',
  'Posso usare smartwatch e app di punteggio in torneo?',
  'Non darlo per scontato: avere l''app o la companion installata non equivale all''autorizzazione a usarla in competizione. Nei principali circuiti FIP 2026 un giocatore o un allenatore non può usare alcun dispositivo elettronico dall''inizio dello scambio (nel rulebook Premier Padel: dal palleggio di riscaldamento) fino alla fine del match — comprese le pause per bagno, cambio d''abbigliamento, time-out medico e interruzioni di gioco — salvo approvazione del Supervisor o del Referee del torneo; l''uso è consentito quando il gioco è ufficialmente sospeso. Chi ha bisogno di un dispositivo per monitorarsi per motivi di salute deve chiedere il permesso al Supervisor. Il regolamento FIP vieta inoltre racchette con dispositivi visibili o sonori che comunichino o diano istruzioni durante il game. Prima di usare Padelandia in gara chiedi al giudice di gara: in caso di dubbio vale la sua decisione.',
  '{"smartwatch","orologio","dispositivo","elettronico","torneo","gara","app","consentito","autorizzazione"}',
  'CUPRA FIP Tour Official Rulebook 2026 e Premier Padel Official Rulebook 2026; FIP Rules of Padel — La racchetta da padel',
  'Sezione 6.1.4(D) Electronic devices di entrambi i rulebook; La racchetta da padel, punto 10',
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

insert into public.rules_faq (id, question, answer, keywords, source, rule_ref, rules_version, example, lang) values (
  'who_calls',
  'Chi decide i punti dubbi senza arbitro?',
  'Nelle partite amatoriali senza arbitro decide la coppia nel cui campo è rimbalzata la palla, in buona fede. In caso di disaccordo la prassi è ripetere il punto. Nei tornei ufficiali decide l''arbitro, che è anche l''unico a poter giudicare la fondatezza di un let.',
  '{"arbitro","dubbio","decidere","chiamata","contestazione"}',
  'Prassi FIP / fair play — partite senza arbitro',
  null,
  '2026.1',
  null,
  'it'
) on conflict (id) do update set
  question = excluded.question, answer = excluded.answer,
  keywords = excluded.keywords, source = excluded.source,
  rule_ref = excluded.rule_ref,
  rules_version = excluded.rules_version,
  example = excluded.example, updated_at = now();

-- Rimuove le voci non più presenti nel dataset locale.
delete from public.rules_faq where lang = 'it'
  and id not in ('scoring_base', 'star_point', 'golden_point', 'tie_break', 'super_tie_break', 'mini_set', 'match_tie_break_7', 'third_set_no_tiebreak', 'serve_how', 'serve_let', 'serve_fault', 'serve_order', 'receive_order', 'receive_position', 'walls_own_side', 'smash_return_own_side', 'grid', 'double_bounce', 'net_touch', 'over_net_reach', 'out_of_court', 'smash_out', 'change_sides', 'ball_hits_player', 'double_hit', 'let_point', 'interference', 'safety_cord', 'ball_change', 'court_size', 'racket_ball', 'warmup_time', 'suspensions_medical', 'penalties', 'electronic_devices_tournaments', 'who_calls');


-- ------------------------------------------------------- knowledge base v2

-- Nuova edizione: fa da fingerprint per la cache dell'assistant, che dopo
-- questa migration non può più servire risposte costruite sul testo vecchio.
insert into public.knowledge_versions (
  version_id, label, description, effective_date, source_scope
)
values (
  'padel_kb_2026_07_fip_2026_1',
  'Momentum Padel Knowledge Base - FIP 2026.1',
  'Allineamento alla FIP Rules of Padel rev. 01.01.2026: Star Point, formati alternativi, cambio campo, posizione del ricevitore, risposta contro la propria parete, tempi di gioco e avvertenza sui dispositivi elettronici in torneo.',
  date '2026-07-27',
  'FIP Rules of Padel 01.01.2026, CUPRA FIP Tour Rulebook 2026, Premier Padel Rulebook 2026.'
)
on conflict (version_id) do update set
  label = excluded.label,
  description = excluded.description,
  effective_date = excluded.effective_date,
  source_scope = excluded.source_scope;

insert into public.knowledge_sources (
  source_id, title, url, source_type, reliability, authority_level,
  accessed_at, published_at, update_cadence, certainty_note, citation
)
values
  (
    'cupra_fip_tour_rulebook_2026',
    'CUPRA FIP Tour Official Rulebook 2026',
    'https://www.padelfip.com/wp-content/uploads/2025/03/Cupra-FIP-Tour-Rulebook_EN-2.pdf',
    'official',
    5,
    'Official FIP circuit regulations',
    date '2026-07-27',
    date '2026-01-01',
    'annual',
    'Regolamento di circuito: condotta, attrezzatura e uso dei dispositivi elettronici in gara.',
    '{"publisher":"International Padel Federation","language":"en","document_type":"circuit_rulebook"}'::jsonb
  ),
  (
    'premier_padel_rulebook_2026',
    'Premier Padel Official Rulebook 2026',
    'https://www.padelfip.com/wp-content/uploads/2025/03/Premier-Padel-Rulebook-Men%C2%B4s_EN.pdf',
    'official',
    5,
    'Official Premier Padel tour regulations',
    date '2026-07-27',
    date '2026-01-01',
    'annual',
    'Regolamento Premier Padel: stessa disciplina sui dispositivi elettronici, estesa al palleggio di riscaldamento.',
    '{"publisher":"Premier Padel / FIP","language":"en","document_type":"circuit_rulebook"}'::jsonb
  )
on conflict (source_id) do update set
  title = excluded.title,
  url = excluded.url,
  source_type = excluded.source_type,
  reliability = excluded.reliability,
  authority_level = excluded.authority_level,
  accessed_at = excluded.accessed_at,
  published_at = excluded.published_at,
  update_cadence = excluded.update_cadence,
  certainty_note = excluded.certainty_note,
  citation = excluded.citation,
  updated_at = now();

insert into public.knowledge_tags (tag, cluster_id, description)
values
  ('star-point', 'scoring_formats', 'Punto decisivo dopo tre parità (Regola 1, Opzione 2).'),
  ('formati', 'scoring_formats', 'Mini-set, tie-break decisivo, terzo set senza tie-break.'),
  ('cambio-campo', 'official_rules', 'Quando si cambia lato del campo.'),
  ('tempi', 'official_rules', 'Riscaldamento, pause, sospensioni e assistenza medica.'),
  ('ricezione', 'official_rules', 'Posizione e ordine di ricezione.'),
  ('dispositivi', 'official_rules', 'Uso di dispositivi elettronici in competizione.')
on conflict (tag) do update set
  cluster_id = excluded.cluster_id,
  description = excluded.description;

-- Topic nuovi e correzioni ai topic esistenti.
insert into public.knowledge_topics (
  topic_id, cluster_id, version_id, title, slug, summary_short,
  summary_extended, watch_summary, difficulty, audience_level, free_tier,
  premium_tier, answer_blocks, source_policy, certainty, publish_state,
  search_text
)
values
  (
    'rule_scoring_base',
    'scoring_formats',
    'padel_kb_2026_07_fip_2026_1',
    'Punteggio base nel padel',
    'punteggio-base-padel',
    'Il padel usa 0, 15, 30, 40 e game. Sul 40 pari il regolamento 2026 prevede tre opzioni: vantaggi, Star Point o Golden Point.',
    'Il punteggio segue la struttura del tennis: 0, 15, 30, 40 e game. La Regola 1 definisce tre opzioni per il 40 pari, da stabilire prima della partita: vantaggi classici (Opzione 1), Star Point con tre parità e due vantaggi (Opzione 2) e Golden Point con punto secco (Opzione 3). Il set si vince a 6 game con 2 di scarto, con tie-break sul 6-6; il match è di norma al meglio dei 3 set. Sono previsti anche formati alternativi: mini-set a 4 game, tie-break decisivo a 7 punti e super tie-break a 10 punti.',
    'Punteggio: 0-15-30-40-game. Sul 40 pari: vantaggi, Star Point o Golden Point.',
    'beginner',
    array['beginner','intermediate'],
    true,
    true,
    '[{"type":"title","text":"Punteggio base"},{"type":"short_answer","text":"0, 15, 30, 40 e game; il 40 pari segue vantaggi, Star Point o Golden Point."},{"type":"source","text":"FIP Rules of Padel, Regola 1 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'punteggio padel game set 15 30 40 parita parità vantaggi star point golden point tie break super tie break mini set formati regola 1'
  ),
  (
    'rule_star_point',
    'scoring_formats',
    'padel_kb_2026_07_fip_2026_1',
    'Star Point',
    'star-point-padel',
    'Star Point: dopo parità 1, vantaggio 1, parità 2 e vantaggio 2, la terza parità si decide con un punto secco.',
    'Lo Star Point è l''Opzione 2 della Regola 1, introdotta nel regolamento in vigore dal 1 gennaio 2026 e usata da Premier Padel e CUPRA FIP Tour. Sul primo 40 pari si chiama parità 1: il punto seguente assegna vantaggio 1; se il vantaggio viene annullato si torna a parità 2, poi vantaggio 2 e infine parità 3. A parità 3 si gioca lo Star Point, punto decisivo che assegna il game. La coppia in risposta sceglie se ricevere da destra o da sinistra, ma i due giocatori non possono scambiarsi le posizioni. Nelle partite di doppio misto il punto decisivo lo riceve una persona dello stesso sesso di chi serve.',
    'Star Point: 3 parità, 2 vantaggi, poi punto secco. Chi risponde sceglie il lato, senza scambiarsi.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Star Point"},{"type":"short_answer","text":"Tre parità e due vantaggi, poi un punto decisivo che vale il game."},{"type":"attention","text":"I giocatori in risposta scelgono il lato ma non possono scambiarsi le posizioni."},{"type":"source","text":"FIP Rules of Padel, Regola 1 Opzione 2 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'star point parita 1 parita 2 parita 3 parità vantaggio 1 vantaggio 2 punto decisivo deuce game misto stesso sesso regola 1 opzione 2'
  ),
  (
    'rule_golden_point',
    'scoring_formats',
    'padel_kb_2026_07_fip_2026_1',
    'Golden point',
    'golden-point-padel',
    'Golden Point: sul 40 pari si gioca subito un punto decisivo; chi risponde sceglie il lato ma non cambia posizione col compagno.',
    'Il Golden Point è l''Opzione 3 della Regola 1: elimina del tutto i vantaggi, quindi al primo 40 pari si disputa un unico punto decisivo che assegna il game. La coppia in risposta sceglie da quale lato ricevere; i due giocatori non possono però scambiarsi le posizioni per ricevere quel punto. Nelle partite di doppio misto il punto decisivo lo riceve una persona dello stesso sesso di chi serve. È la differenza con lo Star Point, che prima del punto secco concede tre parità e due vantaggi.',
    'Sul 40 pari: punto secco. Chi risponde sceglie il lato, senza scambiarsi.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Golden point"},{"type":"short_answer","text":"Sul 40 pari si gioca un punto decisivo che vale il game."},{"type":"attention","text":"I giocatori in risposta scelgono il lato ma non possono scambiarsi le posizioni."},{"type":"source","text":"FIP Rules of Padel, Regola 1 Opzione 3 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'golden point punto de oro punto decisivo quaranta pari parita parità scelta lato risposta game misto regola 1 opzione 3'
  ),
  (
    'rule_alternative_formats',
    'scoring_formats',
    'padel_kb_2026_07_fip_2026_1',
    'Formati alternativi: mini-set, tie-break decisivo, terzo set senza tie-break',
    'formati-alternativi-padel',
    'Oltre al set a 6 game, la Regola 1 prevede mini-set a 4, tie-break decisivo a 7, super tie-break a 10 e terzo set senza tie-break.',
    'La Regola 1 elenca metodi di punteggio alternativi da stabilire prima della partita. Mini-set: il set si vince a 4 game con 2 di scarto e sul 4-4 si gioca il tie-break. Tie-break decisivo a 7 punti: sul risultato di un set pari sostituisce l''ultimo set e decide il match, con 2 punti di scarto. Super tie-break a 10 punti: stessa logica ma fino a 10. Inoltre l''Opzione 1 consente, se stabilito in anticipo, di giocare il terzo set senza tie-break: sul 6-6 si continua fino a 2 game di vantaggio.',
    'Formati: mini-set a 4, tie-break decisivo a 7, super tie-break a 10, terzo set senza tie-break.',
    'intermediate',
    array['intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Formati alternativi"},{"type":"short_answer","text":"Mini-set a 4 game, tie-break decisivo a 7, super tie-break a 10, terzo set a oltranza."},{"type":"attention","text":"Vanno concordati prima dell''inizio della partita."},{"type":"source","text":"FIP Rules of Padel, Regola 1 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'mini set quattro game tie break decisivo sette super tie break dieci terzo set senza tie break oltranza formati alternativi regola 1'
  ),
  (
    'rule_change_of_ends',
    'official_rules',
    'padel_kb_2026_07_fip_2026_1',
    'Cambio di campo',
    'cambio-campo-padel',
    'Si cambia campo dopo il 1°, il 3° e ogni game dispari del set: a fine set solo se il totale dei game è dispari.',
    'La Regola 5 prevede il cambio di campo alla fine del primo, del terzo e di ogni successivo game dispari del set. Ne segue che alla fine di un set si cambia solo quando il totale dei game giocati è dispari, per esempio 6-3 o 7-6: dopo un set pari come 6-0, 6-2 o 6-4 il cambio slitta alla fine del primo game del set successivo. Nel tie-break si cambia ogni 6 punti. Se per errore non si cambia, la correzione va fatta appena scoperta seguendo l''ordine corretto e i punti già giocati restano validi; se l''errore emerge dopo un primo servizio fallito, al battitore resta un solo servizio.',
    'Cambio dopo ogni game dispari. A fine set solo se il totale game è dispari (6-3 sì, 6-4 no).',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Cambio di campo"},{"type":"short_answer","text":"Dopo il 1°, il 3° e ogni game dispari; a fine set solo con totale dispari."},{"type":"attention","text":"Dopo un 6-4 non si cambia: il cambio slitta al primo game del set dopo."},{"type":"source","text":"FIP Rules of Padel, Regola 5 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'cambio campo lato dispari fine set tie break sei punti regola 5 correzione errore'
  ),
  (
    'rule_receiver_position',
    'official_rules',
    'padel_kb_2026_07_fip_2026_1',
    'Posizione e ordine di ricezione',
    'posizione-ricezione-padel',
    'Il ricevitore può stare ovunque nel proprio campo: è la palla servita a dover rimbalzare nel riquadro diagonale.',
    'La Regola 3 stabilisce che riceve il giocatore diagonalmente di fronte al battitore, ma precisa anche che chi riceve può stare in qualunque punto del proprio campo, così come il suo compagno e il compagno del battitore. Nessuno è obbligato a posizionarsi dentro un riquadro: è la palla servita a dover rimbalzare nel riquadro di ricezione diagonale. Il ricevitore deve aspettare quel rimbalzo e colpire prima del secondo. Nel primo game di ogni set la coppia in risposta sceglie chi riceve per primo e l''ordine non cambia fino alla fine del set; se viene alterato durante un game o un tie-break si prosegue così fino al termine di quel game e poi si torna alle posizioni iniziali. Unica eccezione alla libertà di posizione: sul punto decisivo di Star Point e Golden Point i due giocatori in risposta non possono scambiarsi le posizioni.',
    'Chi riceve può stare dove vuole: è la palla a dover rimbalzare nel riquadro diagonale.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Posizione di ricezione"},{"type":"short_answer","text":"Il ricevitore può stare ovunque nel proprio campo."},{"type":"attention","text":"Deve essere la palla servita a rimbalzare nel riquadro diagonale."},{"type":"source","text":"FIP Rules of Padel, Regole 3 e 8 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'ricevitore posizione riquadro diagonale ordine ricezione risposta regola 3 regola 8 errore correzione'
  ),
  (
    'rule_match_times',
    'official_rules',
    'padel_kb_2026_07_fip_2026_1',
    'Tempi di gioco, riscaldamento e sospensioni',
    'tempi-gioco-padel',
    'Riscaldamento obbligatorio di 3 minuti, 20 secondi tra i punti, 90 secondi al cambio campo, 120 a fine set.',
    'La Regola 2 fissa un palleggio di cortesia obbligatorio di 3 minuti. Tra un punto e l''altro sono concessi al massimo 20 secondi, al cambio di campo 90 secondi e alla fine di ogni set 120 secondi; dopo il primo game di ogni set e durante il tie-break il gioco è continuo e il cambio avviene senza pausa, con 20 secondi indicati per il cambio nel tie-break. Chi non è in campo pronto a giocare 10 minuti dopo l''orario ufficiale perde il match a tavolino, salvo forza maggiore. Alla ripresa dopo una sospensione il riscaldamento dipende dalla durata: nessuno fino a 5 minuti, 1 minuto da 5 a 20, 3 minuti oltre 20. In caso di infortunio o condizione medica trattabile si ha diritto a una sola interruzione di 3 minuti per condizione; per incidenti non dipendenti dal gioco l''arbitro può concedere fino a 15 minuti, e fino a 5 minuti per circostanze inusuali come una caduta involontaria.',
    'Riscaldamento 3 minuti. 20 s tra i punti, 90 s al cambio campo, 120 s a fine set.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Tempi di gioco"},{"type":"short_answer","text":"Riscaldamento 3 minuti; 20 s tra i punti, 90 s al cambio campo, 120 s a fine set."},{"type":"source","text":"FIP Rules of Padel, Regola 2 (ed. 01.01.2026)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'riscaldamento tre minuti palleggio cortesia venti secondi novanta centoventi pausa sospensione infortunio medico regola 2'
  ),
  (
    'rule_electronic_devices',
    'official_rules',
    'padel_kb_2026_07_fip_2026_1',
    'Dispositivi elettronici e smartwatch in torneo',
    'dispositivi-elettronici-torneo-padel',
    'Nei circuiti FIP 2026 l''uso di dispositivi elettronici in gara richiede l''approvazione del Supervisor o del Referee.',
    'Avere l''app o la companion da polso installata non equivale al permesso di usarla in competizione. I rulebook 2026 del CUPRA FIP Tour e di Premier Padel, alla sezione 6.1.4(D), stabiliscono che un giocatore o un allenatore non può usare alcun dispositivo elettronico dall''inizio dello scambio — nel testo Premier Padel dal palleggio di riscaldamento — fino alla fine del match, comprese le pause per bagno, cambio d''abbigliamento, time-out medico e ogni interruzione di gioco, salvo approvazione del Supervisor o Referee del torneo; l''uso è invece consentito quando il gioco è ufficialmente sospeso. Chi necessita di un dispositivo per monitorarsi per motivi di salute deve chiedere il permesso al Supervisor. Il regolamento FIP vieta inoltre racchette con dispositivi visibili o sonori che comunichino o diano istruzioni durante il game.',
    'Smartwatch in gara solo con via libera del giudice: l''app installata non basta.',
    'intermediate',
    array['intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Dispositivi elettronici in torneo"},{"type":"short_answer","text":"Serve l''approvazione del Supervisor o Referee per usarli in gara."},{"type":"attention","text":"Avere Momentum installato non è di per sé un''autorizzazione: chiedi al giudice di gara."},{"type":"source","text":"CUPRA FIP Tour e Premier Padel Rulebook 2026, 6.1.4(D)"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'smartwatch orologio dispositivo elettronico torneo gara autorizzazione supervisor referee arbitro app consentito regolamento circuito'
  )
on conflict (topic_id) do update set
  cluster_id = excluded.cluster_id,
  version_id = excluded.version_id,
  title = excluded.title,
  slug = excluded.slug,
  summary_short = excluded.summary_short,
  summary_extended = excluded.summary_extended,
  watch_summary = excluded.watch_summary,
  difficulty = excluded.difficulty,
  audience_level = excluded.audience_level,
  free_tier = excluded.free_tier,
  premium_tier = excluded.premium_tier,
  answer_blocks = excluded.answer_blocks,
  source_policy = excluded.source_policy,
  certainty = excluded.certainty,
  publish_state = excluded.publish_state,
  search_text = excluded.search_text,
  updated_at = now();

-- Risposta contro la propria parete: la 0007 lasciava il topic ambiguo.
update public.knowledge_topics
set summary_short = 'Dopo il rimbalzo puoi giocare le tue pareti e puoi anche colpire la palla contro la tua parete perché scavalchi la rete.',
    summary_extended = 'La Regola 14.1(b) considera corretta la risposta in cui la palla, dopo essere stata colpita, tocca prima una parete del proprio campo e poi rimbalza nel campo avversario: rimandare la palla passando dal proprio vetro è regolare. Restano falli il colpo che finisce sulla griglia metallica o sul terreno del proprio campo e quello che, senza rimbalzare nel campo avversario, colpisce direttamente pareti o griglia avversarie. La palla che arriva dagli avversari, invece, va giocata dopo il rimbalzo a terra: può poi toccare pareti e griglia del tuo campo e restare in gioco.',
    watch_summary = 'Puoi giocare sulla tua parete: la palla deve poi rimbalzare di là. Vietate griglia e terreno tuoi.',
    version_id = 'padel_kb_2026_07_fip_2026_1',
    answer_blocks = '[{"type":"title","text":"Pareti del proprio campo"},{"type":"short_answer","text":"Colpire la palla contro la propria parete è una risposta corretta."},{"type":"attention","text":"Non vale se la palla tocca la tua griglia o il tuo terreno, o se finisce diretta sulle pareti avversarie."},{"type":"source","text":"FIP Rules of Padel, Regola 14.1(b) (ed. 01.01.2026)"}]'::jsonb,
    search_text = 'parete propria vetro sponda rimbalzo risposta corretta regola 14 griglia terreno campo avversario',
    updated_at = now()
where topic_id = 'rule_correct_return';

insert into public.knowledge_topic_tags (topic_id, tag)
values
  ('rule_star_point', 'punteggio'),
  ('rule_star_point', 'star-point'),
  ('rule_star_point', 'watch'),
  ('rule_golden_point', 'star-point'),
  ('rule_alternative_formats', 'punteggio'),
  ('rule_alternative_formats', 'formati'),
  ('rule_scoring_base', 'formati'),
  ('rule_change_of_ends', 'regole'),
  ('rule_change_of_ends', 'cambio-campo'),
  ('rule_change_of_ends', 'watch'),
  ('rule_receiver_position', 'regole'),
  ('rule_receiver_position', 'ricezione'),
  ('rule_receiver_position', 'servizio'),
  ('rule_match_times', 'regole'),
  ('rule_match_times', 'tempi'),
  ('rule_electronic_devices', 'regole'),
  ('rule_electronic_devices', 'dispositivi'),
  ('rule_electronic_devices', 'watch')
on conflict (topic_id, tag) do nothing;

insert into public.knowledge_topic_sources (
  topic_id, source_id, evidence_note, source_page, confidence
)
values
  ('rule_star_point', 'fip_rules_2026', 'Regola 1 Opzione 2: parità 1-3, vantaggi 1-2, Star Point, scelta del lato senza scambio di posizioni, doppio misto.', 'Rule 1, Option 2', 'high'),
  ('rule_golden_point', 'fip_rules_2026', 'Regola 1 Opzione 3: punto decisivo sul 40 pari, scelta del lato senza scambio di posizioni, doppio misto.', 'Rule 1, Option 3', 'high'),
  ('rule_alternative_formats', 'fip_rules_2026', 'Regola 1: mini-set a 4 game, tie-break decisivo a 7, super tie-break a 10, terzo set senza tie-break.', 'Rule 1, Alternative score methods', 'high'),
  ('rule_change_of_ends', 'fip_rules_2026', 'Regola 5: cambio dopo ogni game dispari, ogni 6 punti nel tie-break, correzione degli errori.', 'Rule 5', 'high'),
  ('rule_receiver_position', 'fip_rules_2026', 'Regola 3.2: chi riceve può stare ovunque nel proprio campo. Regola 8: ordine di ricezione e correzione.', 'Rules 3 and 8', 'high'),
  ('rule_match_times', 'fip_rules_2026', 'Regola 2: palleggio di cortesia di 3 minuti, tempi tra i punti e ai cambi, sospensioni e assistenza medica.', 'Rule 2', 'high'),
  ('rule_electronic_devices', 'cupra_fip_tour_rulebook_2026', 'Sezione 6.1.4(D): divieto d''uso di dispositivi elettronici dallo scambio a fine match salvo approvazione del Supervisor/Referee.', '6.1.4 Equipment and Identification', 'high'),
  ('rule_electronic_devices', 'premier_padel_rulebook_2026', 'Sezione 6.1.4(D): stesso divieto, esteso esplicitamente dal palleggio di riscaldamento.', '6.1.4 Apparel and Identifications', 'high'),
  ('rule_electronic_devices', 'fip_rules_2026', 'La racchetta non può avere dispositivi visibili o sonori che comunichino o diano istruzioni durante il game.', 'The padel racket, point 10', 'high'),
  ('rule_correct_return', 'fip_rules_2026', 'Regola 14.1(b): la risposta giocata contro la propria parete è corretta se la palla rimbalza poi nel campo avversario.', 'Rule 14', 'high')
on conflict (topic_id, source_id, evidence_note) do nothing;

insert into public.padel_rules (
  topic_id, rule_number, category, user_question, short_answer,
  detailed_answer, examples, edge_cases, official_source_id
)
values
  (
    'rule_scoring_base',
    'Regola 1',
    'punteggio',
    'Come si contano i punti nel padel?',
    'Si conta 0, 15, 30, 40 e game. Sul 40 pari il formato sceglie fra vantaggi, Star Point e Golden Point.',
    'Il sistema base usa 0, 15, 30, 40 e game. La Regola 1 definisce tre opzioni per il 40 pari, da concordare prima della partita: vantaggi, Star Point e Golden Point. Il set si vince a 6 game con 2 di scarto, con tie-break sul 6-6; esistono anche mini-set a 4 game, tie-break decisivo a 7 e super tie-break a 10.',
    '[{"scenario":"Partita amatoriale","answer":"Decidete prima se giocare vantaggi, Star Point o Golden Point."},{"scenario":"Torneo","answer":"Seguite il formato indicato dal regolamento della competizione."}]'::jsonb,
    '[{"case":"Formato non dichiarato","resolution":"Chiarire prima della partita; in app mostrare tutte le opzioni."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_star_point',
    'Regola 1, Opzione 2',
    'punteggio',
    'Come funziona lo Star Point?',
    'Tre parità e due vantaggi, poi un punto decisivo che assegna il game.',
    'Sul primo 40 pari si chiama parità 1 e il punto seguente assegna vantaggio 1. Se il vantaggio viene annullato si torna a parità 2, poi vantaggio 2 e infine parità 3, dove si gioca lo Star Point. La coppia in risposta sceglie il lato ma i due giocatori non possono scambiarsi le posizioni; nel doppio misto riceve una persona dello stesso sesso di chi serve.',
    '[{"scenario":"Parità 3","answer":"Il punto successivo è lo Star Point e vale il game."},{"scenario":"Vantaggio 2 annullato","answer":"Si va a parità 3, non a un terzo vantaggio."}]'::jsonb,
    '[{"case":"Formato legacy sul companion","resolution":"Alcuni orologi non supportano lo Star Point: l''app blocca il formato invece di degradarlo a Golden Point."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_golden_point',
    'Regola 1, Opzione 3',
    'punteggio',
    'Che cosa succede sul quaranta pari con golden point?',
    'Si gioca un punto decisivo. Chi risponde sceglie il lato, senza scambiarsi con il compagno.',
    'Con il Golden Point il 40 pari non apre alcuna sequenza di vantaggi: si gioca un solo punto e chi lo vince conquista il game. La coppia in risposta sceglie da quale lato ricevere ma i due giocatori non possono scambiarsi le posizioni; nel doppio misto riceve una persona dello stesso sesso di chi serve.',
    '[{"scenario":"40 pari","answer":"Chi risponde sceglie il lato, poi punto secco."},{"scenario":"Doppio misto","answer":"Riceve chi ha lo stesso sesso del battitore."}]'::jsonb,
    '[{"case":"Formato non concordato","resolution":"Fermarsi e concordare prima di servire il punto decisivo."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_alternative_formats',
    'Regola 1, Metodi alternativi',
    'punteggio',
    'Quali formati di punteggio alternativi esistono?',
    'Mini-set a 4 game, tie-break decisivo a 7, super tie-break a 10 e terzo set senza tie-break.',
    'Il mini-set si vince a 4 game con 2 di scarto e sul 4-4 si gioca il tie-break. Sul risultato di un set pari, l''ultimo set può essere sostituito da un tie-break decisivo a 7 punti o da un super tie-break a 10, sempre con 2 punti di scarto. In alternativa, se stabilito prima, il terzo set si gioca senza tie-break e sul 6-6 si prosegue fino a 2 game di vantaggio.',
    '[{"scenario":"Torneo con tempi stretti","answer":"Mini-set a 4 game o tie-break decisivo a 7."},{"scenario":"Un set pari","answer":"Ultimo set sostituito da tie-break a 7 o super tie-break a 10, se previsto."}]'::jsonb,
    '[{"case":"Formato deciso a metà partita","resolution":"Non è ammesso: i metodi alternativi vanno stabiliti prima dell''inizio."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_change_of_ends',
    'Regola 5',
    'regole',
    'Quando si cambia campo?',
    'Dopo il 1°, il 3° e ogni game dispari; a fine set solo se il totale dei game è dispari.',
    'Si cambia campo alla fine di ogni game dispari del set e, nel tie-break, ogni 6 punti. Alla fine di un set il cambio avviene solo se il totale dei game è dispari: dopo 6-0, 6-2 o 6-4 il cambio slitta alla fine del primo game del set successivo. Se per errore non si cambia, la correzione va fatta appena scoperta e i punti già giocati restano validi.',
    '[{"scenario":"Set finito 6-3","answer":"Totale 9, dispari: si cambia subito."},{"scenario":"Set finito 6-4","answer":"Totale 10, pari: si cambia dopo il primo game del set successivo."}]'::jsonb,
    '[{"case":"Set chiuso al tie-break","resolution":"7-6 sono 13 game: si cambia sempre."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_receiver_position',
    'Regole 3 e 8',
    'ricezione',
    'Il ricevitore deve stare nel riquadro diagonale?',
    'No: può stare ovunque nel proprio campo. È la palla servita a dover rimbalzare nel riquadro diagonale.',
    'Riceve il giocatore diagonalmente di fronte al battitore, ma la Regola 3.2 gli lascia libertà di posizione in tutto il proprio campo, come al suo compagno e al compagno del battitore. Il vincolo riguarda la palla: deve rimbalzare nel riquadro di ricezione diagonale, e chi riceve deve colpirla prima del secondo rimbalzo. L''ordine di ricezione si sceglie nel primo game del set e non si cambia fino al set successivo.',
    '[{"scenario":"Ricevitore avanzato a rete","answer":"È regolare: la posizione è libera."},{"scenario":"Ordine di ricezione sbagliato","answer":"Si finisce il game così, poi si torna alle posizioni iniziali."}]'::jsonb,
    '[{"case":"Punto decisivo Star/Golden","resolution":"Lì i due giocatori in risposta non possono scambiarsi le posizioni."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_match_times',
    'Regola 2',
    'regole',
    'Quanto dura il riscaldamento e quali sono le pause?',
    'Palleggio di cortesia obbligatorio di 3 minuti; 20 s tra i punti, 90 s al cambio campo, 120 s a fine set.',
    'La Regola 2 prevede 3 minuti di palleggio di cortesia obbligatorio. Tra i punti sono concessi al massimo 20 secondi, ai cambi di campo 90, a fine set 120. Dopo il primo game di ogni set e durante il tie-break il gioco è continuo e il cambio avviene senza pausa, con 20 secondi indicati per il tie-break. Alla ripresa dopo una sospensione il riscaldamento è nullo fino a 5 minuti di stop, 1 minuto fra 5 e 20, 3 minuti oltre 20. In caso di infortunio trattabile si ha una sola interruzione di 3 minuti per condizione.',
    '[{"scenario":"Prima del match","answer":"3 minuti di palleggio, non 5."},{"scenario":"Sospensione per pioggia di 30 minuti","answer":"Alla ripresa spettano 3 minuti di riscaldamento."}]'::jsonb,
    '[{"case":"Ritardo all''orario ufficiale","resolution":"Dopo 10 minuti il match è perso a tavolino, salvo forza maggiore."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_electronic_devices',
    'CUPRA FIP Tour e Premier Padel Rulebook 2026, 6.1.4(D)',
    'regole',
    'Posso usare lo smartwatch o un''app di punteggio durante un torneo?',
    'Solo se il Supervisor o il Referee del torneo lo approvano: avere l''app installata non basta.',
    'I rulebook 2026 dei circuiti FIP vietano a giocatori e allenatori l''uso di qualsiasi dispositivo elettronico dall''inizio dello scambio — nel testo Premier Padel dal palleggio di riscaldamento — fino alla fine del match, incluse le pause per bagno, cambio d''abbigliamento, time-out medico e ogni interruzione, salvo approvazione del Supervisor o Referee; l''uso resta consentito quando il gioco è ufficialmente sospeso. Per un dispositivo necessario a monitorarsi per motivi di salute serve un permesso esplicito del Supervisor.',
    '[{"scenario":"Torneo CUPRA FIP Tour","answer":"Chiedi l''autorizzazione al Supervisor prima di indossare l''orologio in campo."},{"scenario":"Partita tra amici","answer":"Nessun vincolo: il divieto riguarda le competizioni dei circuiti."}]'::jsonb,
    '[{"case":"Regolamenti in conflitto","resolution":"Prevale la decisione del Supervisor/Referee FIP."}]'::jsonb,
    'cupra_fip_tour_rulebook_2026'
  )
on conflict (topic_id) do update set
  rule_number = excluded.rule_number,
  category = excluded.category,
  user_question = excluded.user_question,
  short_answer = excluded.short_answer,
  detailed_answer = excluded.detailed_answer,
  examples = excluded.examples,
  edge_cases = excluded.edge_cases,
  official_source_id = excluded.official_source_id;

-- FAQ v2: aggiunge Star Point e le correzioni fattuali mancanti.
insert into public.rule_faqs_v2 (
  faq_id, rule_topic_id, question, answer_short, answer_long, watch_answer,
  tags, free_available, premium_available, source_id, certainty
)
values
  (
    'faq_score_how',
    'rule_scoring_base',
    'Come funziona il punteggio nel padel?',
    '0, 15, 30, 40 e game; sul 40 pari dipende dal formato scelto.',
    'Il padel usa il punteggio 0, 15, 30, 40 e game. Prima della partita chiarite quale delle tre opzioni della Regola 1 userete sul 40 pari: vantaggi, Star Point o Golden Point.',
    '0-15-30-40-game. Sul 40 pari: vantaggi, Star Point o Golden Point.',
    array['punteggio','star-point','golden-point','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_star_point_cycle',
    'rule_star_point',
    'Come funziona lo Star Point?',
    'Tre parità e due vantaggi, poi un punto decisivo che vale il game.',
    'Sul primo 40 pari si chiama parità 1 e il punto dopo assegna vantaggio 1. Se il vantaggio viene annullato si torna a parità 2, poi vantaggio 2 e infine parità 3: lì si gioca lo Star Point, il punto che assegna il game.',
    'Parità 1, AD 1, parità 2, AD 2, parità 3: poi punto secco.',
    array['punteggio','star-point','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_star_point_side',
    'rule_star_point',
    'Chi sceglie il lato sullo Star Point?',
    'La coppia in risposta, che però non può scambiarsi le posizioni.',
    'Sullo Star Point la coppia in risposta sceglie se ricevere da destra o da sinistra, ma i due giocatori devono restare nelle rispettive posizioni. Nel doppio misto il punto decisivo lo riceve una persona dello stesso sesso di chi serve.',
    'Star Point: chi risponde sceglie il lato, senza scambiarsi.',
    array['punteggio','star-point','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_golden_point_side',
    'rule_golden_point',
    'Chi sceglie il lato nel golden point?',
    'La coppia in risposta, che però non può scambiarsi le posizioni.',
    'Nel Golden Point sul 40 pari si gioca un punto decisivo. La coppia in risposta sceglie da quale lato ricevere ma i due giocatori non possono scambiarsi le posizioni; nel doppio misto riceve chi ha lo stesso sesso del battitore.',
    'Golden point: chi risponde sceglie il lato, senza scambiarsi.',
    array['golden-point','punteggio','star-point','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_alternative_formats',
    'rule_alternative_formats',
    'Esistono formati più corti del set a 6 game?',
    'Sì: mini-set a 4 game, tie-break decisivo a 7 e super tie-break a 10.',
    'La Regola 1 prevede il mini-set a 4 game con tie-break sul 4-4, il tie-break decisivo a 7 punti e il super tie-break a 10 punti al posto dell''ultimo set. È anche possibile giocare il terzo set senza tie-break, a oltranza. Vanno tutti concordati prima di iniziare.',
    'Mini-set a 4, tie-break decisivo a 7, super tie-break a 10.',
    array['punteggio','formati'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_change_ends_end_of_set',
    'rule_change_of_ends',
    'Si cambia sempre campo alla fine di un set?',
    'No: solo se il totale dei game di quel set è dispari.',
    'Il cambio avviene dopo ogni game dispari del set. Alla fine di un set si cambia quindi solo con un totale dispari, per esempio 6-3 o 7-6; dopo un 6-0, 6-2 o 6-4 il cambio slitta alla fine del primo game del set successivo.',
    'Fine set: 6-3 sì, 6-4 no. Si cambia dopo il primo game dopo.',
    array['regole','cambio-campo','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_receiver_position',
    'rule_receiver_position',
    'Il ricevitore deve stare nel riquadro diagonale?',
    'No, può stare ovunque nel proprio campo.',
    'La Regola 3 consente a chi riceve, al suo compagno e al compagno del battitore di stare in qualunque punto del proprio campo. È la palla servita a dover rimbalzare nel riquadro di ricezione diagonale, e va colpita prima del secondo rimbalzo.',
    'Posizione libera: è la palla a dover rimbalzare nel riquadro.',
    array['regole','ricezione','servizio','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_own_wall_return',
    'rule_correct_return',
    'Posso mandare la palla sulla mia parete per farla passare di là?',
    'Sì: è una risposta corretta se poi la palla rimbalza nel campo avversario.',
    'La Regola 14.1(b) considera corretta la risposta in cui la palla colpita tocca prima una parete del proprio campo e poi rimbalza nel campo avversario. Perdi invece il punto se la palla tocca la tua griglia metallica o il tuo terreno, o se finisce diretta su pareti o griglia avversarie senza rimbalzare prima nel loro campo.',
    'Sì, sulla tua parete si può: deve poi rimbalzare di là.',
    array['pareti','regole','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_warmup_time',
    'rule_match_times',
    'Quanto dura il riscaldamento prima di una partita ufficiale?',
    'Tre minuti di palleggio di cortesia obbligatorio.',
    'La Regola 2 prevede 3 minuti di palleggio di cortesia obbligatorio prima del match. Tra i punti sono concessi al massimo 20 secondi, ai cambi di campo 90 secondi e alla fine di ogni set 120 secondi.',
    'Riscaldamento: 3 minuti. Poi 20 s tra i punti.',
    array['regole','tempi','watch'],
    true, true, 'fip_rules_2026', 'official'
  ),
  (
    'faq_tournament_devices',
    'rule_electronic_devices',
    'Posso usare lo smartwatch con Momentum durante un torneo?',
    'Solo con l''approvazione del Supervisor o del Referee del torneo.',
    'Nei circuiti FIP 2026 giocatori e allenatori non possono usare dispositivi elettronici dall''inizio dello scambio (per Premier Padel dal palleggio di riscaldamento) fino alla fine del match, salvo approvazione del Supervisor o Referee. Avere l''app o la companion installata non è di per sé un''autorizzazione: chiedi al giudice di gara prima di scendere in campo.',
    'In gara serve l''ok del giudice: l''app installata non basta.',
    array['regole','dispositivi','watch'],
    true, true, 'cupra_fip_tour_rulebook_2026', 'official'
  )
on conflict (faq_id) do update set
  rule_topic_id = excluded.rule_topic_id,
  question = excluded.question,
  answer_short = excluded.answer_short,
  answer_long = excluded.answer_long,
  watch_answer = excluded.watch_answer,
  tags = excluded.tags,
  free_available = excluded.free_available,
  premium_available = excluded.premium_available,
  source_id = excluded.source_id,
  certainty = excluded.certainty;

commit;
