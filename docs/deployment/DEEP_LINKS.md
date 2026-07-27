# Momentum Universal Links e Android App Links

La navigazione interna e lo schema `rallymate://` sono gia attivi. I link HTTPS
richiedono invece un dominio realmente controllato e i file di associazione
firmati dalla configurazione finale degli store. Non inserire un dominio di
esempio nella build di produzione.

## Valori necessari

- `RALLYMATE_LINK_BASE_URL`: origine HTTPS, per esempio
  `https://<YOUR_LINK_DOMAIN>` (senza path finale).
- Apple Team ID: quello corrente del progetto e `5KWK3L6AU2`.
- iOS bundle ID: `com.rallymate.rallymate`.
- Android package: `com.rallymate.rallymate`.
- SHA-256 del certificato con cui Google Play distribuisce davvero l'app.
- URL App Store e Google Play definitivi per la pagina fallback.

## File da pubblicare

1. Sostituire i placeholder in
   `deep-links/apple-app-site-association.example.json` e pubblicare il file,
   senza estensione, su:
   `https://<YOUR_LINK_DOMAIN>/.well-known/apple-app-site-association`.
2. Sostituire `YOUR_PLAY_APP_SIGNING_SHA256` in
   `deep-links/assetlinks.example.json` e pubblicare su:
   `https://<YOUR_LINK_DOMAIN>/.well-known/assetlinks.json`.
3. Pubblicare una pagina fallback per `/invite/*` e `/recap/*`. Il template
   `deep-links/invite-fallback.example.html` non raccoglie dati e conserva il
   codice solo nel path corrente.

Entrambi i file `.well-known` devono essere serviti con HTTPS valido, status
`200`, senza redirect e con `Content-Type: application/json`.

## Attivazione nei progetti nativi

Solo dopo che il dominio e operativo:

- iOS: aggiungere `applinks:<YOUR_LINK_DOMAIN>` alla capability Associated
  Domains del target Runner. Non aggiungerla al target watchOS.
- Android: aggiungere un intent filter HTTPS con `android:autoVerify="true"`,
  host `<YOUR_LINK_DOMAIN>` e path prefix `/invite` e `/recap` alla
  `MainActivity`.
- Flutter: mantenere disabilitato il deep-link handler automatico Flutter,
  perche il package `app_links` e il router Momentum gestiscono gia cold start
  e link ricevuti a processo attivo.

Build di verifica:

```bash
flutter build appbundle \
  --dart-define=RALLYMATE_LINK_BASE_URL=https://<YOUR_LINK_DOMAIN>

flutter build ipa \
  --dart-define=RALLYMATE_LINK_BASE_URL=https://<YOUR_LINK_DOMAIN>
```

## Verifica

```bash
curl -i https://<YOUR_LINK_DOMAIN>/.well-known/apple-app-site-association
curl -i https://<YOUR_LINK_DOMAIN>/.well-known/assetlinks.json

xcrun simctl openurl booted https://<YOUR_LINK_DOMAIN>/invite/TEST_TOKEN
adb shell am start -a android.intent.action.VIEW \
  -d https://<YOUR_LINK_DOMAIN>/invite/TEST_TOKEN
adb shell pm get-app-links com.rallymate.rallymate
```

Il token reale e opaco, scade ed e revocabile nel backend. L'app mostra sempre
l'identita dell'invitante e richiede conferma prima di creare relazioni.

## Installazione differita

Firebase Dynamic Links non e una dipendenza valida per un nuovo progetto. Il
flusso Momentum usa link HTTPS, QR e codice breve: dopo una nuova installazione
l'utente puo inserire o scansionare lo stesso codice. Un deferred deep-link
automatico richiederebbe un provider dedicato e una valutazione privacy separata;
non va dichiarato negli store finche non viene scelto e verificato.

