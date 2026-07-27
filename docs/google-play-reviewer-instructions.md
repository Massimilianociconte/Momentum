# Istruzioni per il revisore Google Play — Momentum

Testo da inserire in Play Console → App content → "App access" / note per la review. Fornito in inglese (lingua della review) con riferimenti interni.

## App access (testo per la Console, EN)

```
Momentum is a padel scoring and training companion app.

TEST ACCOUNT
Most features work without an account (local scoring, rules, analytics on
local data). Cloud features (social, backup, AI assistant, subscriptions)
require sign-in.

Email:    <CREARE ACCOUNT DI TEST DEDICATO>
Password: <PASSWORD ACCOUNT DI TEST>

Sign-in path: open the app → complete/skip onboarding → Profile tab →
"Accedi" → email + password.

SUBSCRIPTIONS
Subscriptions (Plus / Pro / Coach) are purchased via Google Play Billing
(managed by RevenueCat). Use a license-tester Google account to test
purchases without charges. Premium screens are reachable from
Profile → "Premium".

HEALTH CONNECT
The app reads aggregated fitness data (steps, active calories, heart rate,
exercise sessions, HRV, sleep) from Health Connect, read-only, last 7 days
max, to show recovery/readiness insights. The permission rationale is shown
in-app under Profile → "Privacy e dati" and is also opened when the system
requests ACTION_SHOW_PERMISSIONS_RATIONALE. Health data never leaves the
device except for optional encrypted premium backup explicitly enabled by
the user.

WEAR OS COMPANION
The Wear OS app (same package, bundled in this release) is standalone:
scoring works offline on the watch. Pairing with the phone via the Data
Layer is optional and automatic when both apps are installed.

ACCOUNT DELETION
In-app: Profile → account section → "Elimina account" (double confirmation,
type "ELIMINA"). Web: the URL declared in Data deletion section shows
instructions and performs deletion for authenticated requests.

AI ASSISTANT
The assistant answers padel rules/technique questions. It is quota-limited
server-side; no health data is included in prompts.
```

## Note operative (interne, non incollare)

- Creare l'account di test su Supabase produzione prima della submission; non riutilizzare account personali.
- Aggiungere l'account Google del revisore non è possibile: usare License testing (Play Console → Settings → License testing) con l'account interno usato per i test di acquisto.
- Se la review chiede video: registrare il flusso Health Connect (richiesta permessi + rationale) e la cancellazione account.
- Rispondere ai rilievi della review entro 7 giorni per non far scadere la release.
