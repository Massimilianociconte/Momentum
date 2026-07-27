# Procedura di release e rollback — Momentum

## 1. Versioning

| Artefatto | versionCode | versionName | Fonte |
|---|---|---|---|
| Telefono | N (da `pubspec.yaml`, `0.1.0+1` → 1) | 0.1.0 | pubspec |
| Wear OS | 1000 + N (attuale: 1001) | 0.1.0 | `wear/wearos/app/build.gradle.kts` |

Regola: a ogni release incrementare il build number nel pubspec (`0.1.0+2` → phone 2) e allineare il Wear a `1002`. I due range non devono mai sovrapporsi (il telefono resta < 1000).

## 2. Build store (locale, mai in CI)

```bash
# Prerequisiti: keystore upload fuori dal repo + env di produzione
export RALLYMATE_ANDROID_KEYSTORE_PATH=... \
       RALLYMATE_ANDROID_KEYSTORE_PASSWORD=... \
       RALLYMATE_ANDROID_KEY_ALIAS=... \
       RALLYMATE_ANDROID_KEY_PASSWORD=...

# Telefono (valida config produzione: URL https, sb_publishable_, goog_)
cd apps/momentum
RALLYMATE_CLIENT_ENV=/percorso/prod.env tool/rallymate build-appbundle
# → build/app/outputs/bundle/release/app-release.aab

# Wear OS (stesse env var → stesso certificato, obbligatorio)
cd ../../wear/wearos
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew bundleRelease
# → app/build/outputs/bundle/release/app-release.aab
```

Verifiche post-build prima dell'upload:
- [ ] `jarsigner -verify` o `apksigner verify --print-certs` sui due artefatti → stesso certificato.
- [ ] Aprire l'AAB telefono con bundletool e controllare versionCode/targetSdk attesi.
- [ ] Smoke test dell'APK universale generato da bundletool su device fisico.

## 3. Rollout

1. Upload nel track (closed → produzione dopo i 14 giorni).
2. Produzione con **staged rollout**: 10% → monitor 48h → 50% → monitor 48h → 100%.
3. Durante il rollout monitorare: Android Vitals (crash < 1.09%, ANR < 0.47%), recensioni, log edge functions Supabase, dashboard RevenueCat.

## 4. Rollback

Google Play **non permette** di ripubblicare un versionCode inferiore. Opzioni in ordine di preferenza:

1. **Halt rollout**: se il problema emerge durante lo staged rollout, fermare la percentuale (Console → Release → Halt). Gli utenti già aggiornati restano sulla versione difettosa.
2. **Hotfix in avanti**: correggere, incrementare versionCode (phone N+1, wear 100x+1), upload, rollout accelerato al 100%. È il rollback effettivo.
3. **Kill-switch lato server** (senza release): le feature cloud critiche possono essere disattivate da Supabase (es. disabilitare edge function, revocare secrets del provider difettoso). Vale per: assistente, push, health provider cloud, webhook billing. Lo scoring locale non è mai coinvolto.

Playbook hotfix (target < 24h):
1. Branch da tag della release difettosa, fix minimale, test suite completa.
2. Bump versioni, build §2, upload in produzione con rollout 100% (o 50% se il fix è rischioso).
3. Postmortem: aggiungere test di regressione e, se serve, riga in `known-risks.md`.

## 5. Tag e tracciabilità

- Taggare ogni release: `git tag android-v0.1.0+1` (phone) — il wear è implicito (1001).
- Conservare AAB + mapping file R8 (`build/app/outputs/mapping/release/mapping.txt`): caricare il mapping in Play Console per la deobfuscation dei crash (obbligatorio con minify attivo).
- Annotare in changelog interno: versioni, dart-define usati (senza valori segreti), commit.
