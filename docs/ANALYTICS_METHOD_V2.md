# Momentum Performance Intelligence v2

**Metodo tecnico · versione 2 · 13 luglio 2026**

## Scopo e confini

Performance Intelligence elabora una partita **solo dopo il replay completo**
della timeline canonica degli eventi. Non assegna etichette di momentum al
singolo punto in diretta e non usa dati salute, AI generativa o servizi remoti.
Le metriche sono descrittive e indicative: non costituiscono una previsione,
una classifica federale, una valutazione medica o una garanzia di rendimento.

L'input e' la sequenza idempotente dei punti effettivi dopo l'applicazione
degli undo. Ogni punto contiene punteggio prima/dopo, battitore, game, set,
tie-break e squadra vincitrice. Il risultato e' salvato come cache JSON
versionata e puo' sempre essere rigenerato dagli eventi originali.

## Metodo

### Tassi e incertezza

Punti, servizio, risposta, pressione, break, salvataggi e chiusura sono
conteggi binomiali. Momentum mostra sempre successi/campione e un intervallo
di Wilson bilaterale al 90%, che resta definito anche con campioni piccoli e
non produce l'illusione di precisione degli intervalli Wald.

Riferimento: [NIST/SEMATECH, confidence limits for a binomial proportion](https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm).

### Importanza strutturale del punto

Un modello di Markov assorbente del punteggio calcola, per ciascuno stato, la
probabilita' neutrale di vincere la partita assumendo rally indipendenti al
50%. La **leva** di un punto e' la differenza tra lo scenario in cui quel rally
viene vinto e quello in cui viene perso. Misura quindi l'importanza imposta
dal formato e dal punteggio, non la probabilita' reale che un giocatore vinca.

Riferimenti metodologici: [Newton e Keller, Probability of Winning at Tennis](https://onlinelibrary.wiley.com/doi/10.1111/j.0022-2526.2005.01547.x)
e [Kovalchik, point importance in a finite-state scoring model](https://www.tandfonline.com/doi/abs/10.1080/02701367.2019.1666203).

I punti di pressione sono selezionati dalla parte alta della distribuzione di
leva della partita, includendo esplicitamente set point e match point. Il
valore clutch e' una stima empirical-Bayes: il tasso nei punti di pressione e'
regolarizzato verso il tasso personale della stessa partita. Se non esiste un
campione di pressione il valore resta assente, non viene inventato un 50%.

### Turning point confermati

Un punto ad alta leva diventa turning point solo se chiude set/partita oppure
se la sua direzione e' sostenuta dalla finestra di punti successiva. Questo
evita di descrivere retrospettivamente come decisivo ogni scambio appariscente.
Eventi adiacenti vengono deduplicati privilegiando la chiusura piu' importante.

### Fasi persistenti e momentum

La sequenza binaria dei rally viene segmentata offline mediante partizionamento
ottimo a verosimiglianza penalizzata, con lunghezza minima dei segmenti. Una
fase viene pubblicata solo quando il relativo intervallo di Wilson e' separato
dal livello medio della partita. Il metodo riprende i principi della detection
di change point e della penalizzazione usati da PELT, ma usa una soluzione
esatta quadratica perche' una partita contiene pochi eventi.

Riferimenti: [Killick, Fearnhead ed Eckley, Optimal Detection of Changepoints](https://www.tandfonline.com/doi/abs/10.1080/01621459.2012.737745)
e [Adams e MacKay, Bayesian Online Changepoint Detection](https://arxiv.org/abs/0710.3742).

## Aggregazione tra partite

- I conteggi vengono sommati prima di calcolare i tassi: una partita da 10
  punti non pesa quanto una da 150.
- I confronti tra periodi usano quote normalizzate e richiedono campioni
  minimi e intervalli separati; non confrontano punti assoluti tra formati
  diversi.
- Evidenza `INSUFFICIENT`: meno di 3 partite o 140 rally.
- Evidenza `DEVELOPING`: almeno 3 partite e 140 rally.
- Evidenza `RELIABLE`: almeno 8 partite e 500 rally.

Le soglie di prodotto regolano quando mostrare un insight e non certificano
validita' scientifica individuale. Devono essere rivalutate su dati aggregati
anonimi soltanto dopo consenso e una separata valutazione privacy.

## Dati, privacy e versionamento

- Elaborazione deterministica sul dispositivo; nessuna chiamata LLM/backend.
- Nessun dato HealthKit, Health Connect o frequenza cardiaca entra nel motore.
- Il backup Premium salva gli eventi sportivi consentiti; l'analisi derivata
  viene ricalcolata per evitare copie incoerenti.
- `AdvancedMatchAnalysis.currentVersion` governa la migrazione lazy delle
  cache precedenti. Una modifica metodologica richiede una nuova versione,
  test di regressione e aggiornamento di questo documento.
- La UI deve mostrare campione, qualita' dell'evidenza e natura indicativa dei
  modelli; non deve usare claim medici, diagnostici o di ranking ufficiale.

## Controlli di qualita'

La suite automatica copre campioni piccoli, assenza di pressione, tie-break,
undo, deduplicazione, segmentazione persistente, serializzazione versionata e
aggregazione pesata. La validazione futura consigliata e' un confronto
prospettico con annotazioni indipendenti di coach qualificati, senza usare lo
stesso risultato finale per definire e validare il pattern.
