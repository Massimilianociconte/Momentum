# Manifest asset salute e wearable

Data: 13 luglio 2026

## Specifica comune

- formato: PNG RGBA;
- dimensione: 960x720 (4:3);
- sfondo: trasparente, senza pannelli o rettangoli incorporati;
- integrazione: la card usa `RallyColors.surface` (`#16202F`) sopra
  `RallyColors.night` (`#0C1220`), quindi l'asset eredita sempre il colore
  effettivo della UI;
- contenuto: prodotto isolato e realistico, illuminazione lime/cyan Momentum,
  nessuna schermata, metrica o capability inventata;
- budget: meno di 600 KB per asset;
- QA automatico: oltre 75% pixel trasparenti, zero fondo bianco opaco e fascia
  esterna di 24 px interamente trasparente.

## File

| Asset | Uso | Dimensione indicativa | Direzione Imagen riproducibile |
|---|---|---:|---|
| `device_oura_ring_onboarding.png` | Oura hub e direct | 287 KB | anello smart nero premium, sensori interni visibili, vista prodotto isolata |
| `device_whoop_onboarding.png` | WHOOP direct | 444 KB | fascia fitness senza display, tessuto tecnico nero, accenti Momentum |
| `device_helio_strap_onboarding.png` | Helio Strap via hub | 401 KB | fascia biometrica da braccio, modulo realistico, posa pubblicitaria pulita |
| `device_ringconn_onboarding.png` | RingConn via hub | 391 KB | smart ring elegante con dettagli sensore, nessuna UI inventata |
| `device_ultrahuman_onboarding.png` | Ultrahuman via hub | 404 KB | smart ring premium isolato, metallo scuro, riflessi lime/cyan controllati |
| `device_ble_hr_sensor_onboarding.png` | pairing HRS BLE | 358 KB | fascia toracica/sensore cardiaco standard, forma comprensibile e neutra |

Percorso: `apps/momentum/assets/onboarding/health/`.

## Regole di utilizzo

1. Non appiattire la trasparenza esportando JPG/WebP con fondo.
2. Non riusare questi asset per dichiarare scoring su dispositivi health-only.
3. Non mostrare l'asset di un provider con stato `RESEARCH` o
   `NOT_SUPPORTED` in una superficie pubblica.
4. Aggiornare test, catalogo e questo manifest insieme quando viene aggiunto
   un provider.
5. Verificare almeno una schermata iOS e Android reale dopo ogni rigenerazione.

## Evidenza integrata

- iOS: `docs/evidence/health-provider-oura-ios.png`
- Android: `docs/evidence/health-provider-oura-android.png`

Entrambe mostrano che la trasparenza elimina l'effetto etichetta e lascia
coincidere esattamente il fondale del prodotto con la card Momentum.

