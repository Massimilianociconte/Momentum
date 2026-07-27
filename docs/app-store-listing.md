# App Store listing (Apple) — Momentum

Scheda per App Store Connect. Regole Apple applicate: il nome e il
sottotitolo sono indicizzati; il campo keyword (100 caratteri) NON deve
ripetere parole già presenti in nome/sottotitolo né "app" o il nome della
categoria (aggiunti automaticamente da Apple); virgole senza spazi; niente
nomi di competitor o marchi altrui (motivo di rejection, guideline 2.3.7).

## Localizzazione it-IT (primaria)

### Nome (max 30 caratteri)

```
Momentum: Segnapunti Padel
```
(26 caratteri — keyword primaria "segnapunti padel" nel nome)

### Sottotitolo (max 30 caratteri)

```
Punti dal polso, anche offline
```
(30 caratteri — value proposition + keyword "offline")

### Campo keyword (max 100 caratteri, virgole senza spazi)

```
punteggio,contapunti,tabellone,tennis,racchetta,partita,match,watch,orologio,statistiche,sport
```
(94 caratteri — nessuna parola duplicata da nome/sottotitolo; singolari:
Apple indicizza automaticamente i plurali)

### Testo promozionale (max 170 caratteri, modificabile senza review)

```
Segna i punti del padel da Apple Watch o iPhone, anche senza connessione.
Golden point, tie-break, storico partite e statistiche descrittive.
```
(146 caratteri)

### Descrizione (max 4000 caratteri — non indicizzata da Apple: scritta per
la conversione, non per le keyword)

```
Momentum è il segnapunti per il padel pensato per chi gioca davvero:
registri il punteggio dal polso o dal telefono, anche senza connessione,
e ritrovi ogni partita nello storico con analisi chiare e oneste.

SEGNA I PUNTI DAL POLSO
• App nativa per Apple Watch: un tocco per punto, vibrazione di conferma
• Golden point o vantaggi, tie-break e super tie-break
• Undo illimitato: ogni punto è un evento, niente si perde
• Pausa e ripresa della partita, anche cambiando dispositivo

FUNZIONA OFFLINE
• Il punteggio vive sul dispositivo: il campo non ha bisogno di Wi-Fi
• Telefono e orologio si riallineano da soli appena torna la connessione
• Nessun account richiesto per segnare i punti

LO STORICO CHE SI LEGGE
• Cronologia completa: set, game, punti decisivi
• Statistiche descrittive con campione e limiti dichiarati
• Andamento nel tempo, senza classifiche gonfiate né previsioni

SOCIAL E SQUADRE
• Trova compagni di gioco, crea squadre e gruppi con classifiche
• Modalità Duo per i tornei in coppia
• Area coach per allenatori e atleti

ASSISTENTE AI
• Risposte su regole, tecnica e tattica del padel
• Basato su una knowledge base curata, citata e verificabile

PRIVACY AL PRIMO POSTO
• I dati salute restano sul dispositivo (solo lettura, solo aggregati)
• Backup cloud cifrato opzionale (premium)
• Eliminazione account direttamente dall'app
• Nessuna pubblicità

ABBONAMENTI
Momentum è gratuita. Le funzioni avanzate sono disponibili con gli
abbonamenti Plus, Pro e Coach, gestiti tramite App Store. Prezzi e
condizioni sono mostrati nell'app prima dell'acquisto.

Termini: https://playmomentum.it/termini/
Privacy: https://playmomentum.it/privacy/
```

## Localizzazione en-US (aggiungere en-GB con lo stesso testo)

### Name (max 30 characters)

```
Momentum: Padel Scorekeeper
```
(27 characters)

### Subtitle (max 30 characters)

```
Score from your wrist, offline
```
(30 characters)

### Keyword field (max 100 characters)

```
scoreboard,tennis,racket,match,tracker,stats,watch,counter,sport,points,game,court
```
(82 characters — no duplicates from name/subtitle)

### Promotional text (max 170 characters)

```
Keep padel score from Apple Watch or iPhone, even with no connection.
Golden point, tie-breaks, match history and honest descriptive stats.
```
(139 characters)

### Description

Traduzione fedele della descrizione it-IT (stessa struttura a sezioni).

## Localizzazione es-ES (Spagna — primo mercato mondiale del pádel; aggiungere es-MX con lo stesso testo)

### Nombre (max 30 caratteri)

```
Momentum: Marcador de Pádel
```
(27 caratteri — keyword primaria "marcador de pádel", coerente con IT/EN)

### Subtítulo (max 30 caratteri)

```
Puntúa desde tu reloj, offline
```
(30 caratteri — value proposition + keyword "offline")

### Campo keyword (max 100 caratteri, virgole senza spazi)

```
puntuacion,contador,tenis,pala,partido,match,smartwatch,estadisticas,deporte,pista,puntos
```
(90 caratteri — senza accenti: Apple normalizza; nessun duplicato da
nome/sottotitolo — "puntuacion"/"puntos" non collidono con "puntúa")

### Texto promocional (max 170 caratteri)

```
Anota los puntos del pádel desde el Apple Watch o el iPhone, incluso sin
conexión. Punto de oro, tie-break, historial de partidos y estadísticas.
```
(146 caratteri)

### Descripción

Traduzione fedele della descrizione it-IT; il testo completo es-ES per la
sezione descrittiva è in `docs/play-store-listing-es.md` (stessa struttura,
adattare i riferimenti da Google Play ad App Store nella sezione
abbonamenti).

## Note operative

| Campo | Valore |
|---|---|
| Categoria primaria | Sports |
| Categoria secondaria | Health & Fitness |
| URL supporto | https://playmomentum.it/supporto/ |
| URL marketing | https://playmomentum.it |
| Privacy policy URL | https://playmomentum.it/privacy/ |
| EULA | Standard Apple (nessuna EULA custom) |
| Screenshot | Vedi `docs/play-store-assets-checklist.md` §didascalie OCR |

- **Product Page Optimization (A/B nativo Apple)**: dopo il lancio testare
  prima l'ordine dei primi 2 screenshot, poi il sottotitolo. Una variabile
  alla volta, minimo 2 settimane di dati.
- **Custom Product Pages**: creare una pagina dedicata "Apple Watch" da
  usare nelle campagne rivolte a chi possiede lo smartwatch.
- **Recensioni**: usare `SKStoreReviewController` dopo la terza partita
  completata (momento di soddisfazione), mai dopo un errore.
- Il campo keyword si può aggiornare solo con una nuova build: pianificare
  le revisioni keyword insieme alle release.
