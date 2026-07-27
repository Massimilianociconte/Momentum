# Checklist asset grafici Play Store — Momentum

Tutti gli asset vanno prodotti prima della submission. Nessuno può contenere badge di store, prezzi o claim di ranking ("app n.1").

## Obbligatori

| Asset | Specifiche | Stato | Note |
|---|---|---|---|
| Icona app | 512×512 PNG, 32-bit, ≤ 1 MB, senza trasparenza sugli angoli (Google applica la maschera) | ✅ PRONTA | `docs/store-assets/google-play/play-store-icon-512.png` (generata dall'icona brand 1024, no alpha, 193 KB) |
| Feature graphic | 1024×500 JPG/PNG, no testo essenziale ai bordi | DA PRODURRE | Visual con campo padel + watch + telefono |
| Screenshot telefono | Min 4 (consigliati 8), 16:9 o 9:16, min 320 px, max 3840 px | DA PRODURRE | Scoreboard, statistiche, social, assistente, privacy |
| Screenshot Wear OS | Min 1 (consigliati 3), rotondi 1:1 (384×384 o superiori), su sfondo reale watch | DA PRODURRE | Esistono già catture in `artifacts/watch-score-fix/` per Apple Watch: NON usarle per Wear OS (devono mostrare l'app Wear OS reale) |

## Consigliati

| Asset | Specifiche | Note |
|---|---|---|
| Screenshot tablet 7" | Min 1 se si dichiara supporto tablet | L'app è un'app telefono; valutare se limitare i form factor |
| Video promo | URL YouTube pubblico | Opzionale |

## Screenshot suggeriti (telefono, 9:16)

1. Scoreboard match in corso (golden point visibile)
2. Cronologia match + undo
3. Statistiche/analytics
4. Home con insight recupero (Health Connect)
5. Social: squadre e gruppi
6. Assistente AI in chat
7. Schermata Premium (senza prezzi hardcoded nello screenshot)
8. Schermata "Privacy e dati"

## Didascalie screenshot (regole ASO 2026)

Valgono per Google Play E per l'App Store: Apple estrae il testo delle
didascalie via OCR e lo usa per l'indicizzazione keyword, quindi le
didascalie sono anche un segnale di discovery, non solo di conversione.

- Massimo 7 parole per didascalia, ricche di keyword: «Segna i punti dal
  polso», «Funziona offline, sempre», «Storico partite e statistiche» —
  MAI frasi vuote tipo «Facile da usare» o «Design bellissimo».
- Alto contrasto (testo chiaro su sfondo scuro del brand): se l'OCR non
  legge il testo, non viene indicizzato. Corpo ≥ 40 pt sul canvas.
- Value proposition nel PRIMO screenshot, testo in alto a sinistra (bias
  di lettura top-left); mai aprire con una schermata di login.
- La decisione d'installazione avviene in ~7 secondi: i primi 2 screenshot
  devono raccontare da soli «segnapunti padel dal polso, offline».
- Social proof appena disponibile (es. «4,8 ★ su App Store», «10.000+
  partite segnate»): solo dati reali e verificabili, mai inventati.
- Didascalie localizzate IT/EN; testare l'ordine dei primi 2 screenshot
  con gli esperimenti nativi degli store prima di considerarlo definitivo.

## Regole di conformità asset

- Non mostrare dati personali reali negli screenshot (usare account demo).
- Se gli screenshot mostrano dati Health Connect, devono riflettere il comportamento reale (solo aggregati).
- Il device frame è ammesso; le didascalie sovrapposte devono essere localizzate IT/EN.
