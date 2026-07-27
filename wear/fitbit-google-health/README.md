# Momentum Google Health / Fitbit Air

Fitbit Air is screenless. It is integrated as a health data source through the
official Google Health API and cannot host Momentum's live scoring UI. Live
Fitbit scoring is a separate Fitbit OS module in `../fitbit-os`.

Google Health data arrives after provider/device synchronization. It is not a
real-time wearable callback and cannot open Momentum or display an interactive
match prompt on Fitbit Air. Pixel Watch uses the separate Wear OS Health
Services implementation.

## Implemented Architecture

- Pro-only OAuth flow in `functions/google-health/index.ts`.
- Server-side authorization-code exchange and refresh; no Google secret or
  provider token is present in Flutter.
- AES-256-GCM token encryption with per-user additional authenticated data.
- Read-only scopes for activity/fitness and health measurements.
- Calendar-day rollups for steps, active energy, active minutes and optional
  average heart rate through `dataPoints:dailyRollUp`.
- 15-minute refresh while the mobile app is active plus signed Google webhook
  processing.
- Maximum 30-day retention for daily summaries.
- Disconnect revokes Google consent, destroys encrypted tokens and deletes
  Momentum summaries.
- RLS exposes only a user's own aggregate rows; token tables stay server-only.

The requested day is a civil day from 00:00 to the following 00:00, not a
rolling 24-hour window. The device/provider remains responsible for source data
quality and sync latency.

## Server Secrets

```bash
supabase secrets set \
  GOOGLE_HEALTH_CLIENT_ID='<google-oauth-client-id>' \
  GOOGLE_HEALTH_CLIENT_SECRET='<google-oauth-client-secret>' \
  GOOGLE_HEALTH_REDIRECT_URI='https://<project-ref>.supabase.co/functions/v1/google-health' \
  WEARABLE_TOKEN_ENCRYPTION_KEY='<base64-of-exactly-32-random-bytes>' \
  GOOGLE_HEALTH_WEBHOOK_AUTHORIZATION='Bearer <random-webhook-credential>' \
  RALLYMATE_ALLOWED_ORIGINS='https://<public-rallymate-domain>'
```

Generate the encryption key locally without storing it in shell history:

```bash
openssl rand -base64 32
```

Deploy both endpoints with their documented manual JWT validation:

```bash
supabase functions deploy google-health --no-verify-jwt
supabase functions deploy google-health-webhook --no-verify-jwt
```

The OAuth redirect URI configured in Google Cloud must exactly match
`GOOGLE_HEALTH_REDIRECT_URI`. Configure Google Health webhook delivery to the
second function and send the exact authorization header stored in the secret.

## Provider Approval And Release

1. Enable Google Health API and configure OAuth consent, verified domains,
   privacy policy and terms URLs.
2. Request only the two scopes declared in `_shared/google_health.ts`.
3. Complete Google's verification and Health API policy review. Google requires
   an independent security assessment before scaling beyond 100 users.
4. Declare Health and Fitness collection in Play Data Safety and App Store
   privacy labels because these opt-in aggregates reach Momentum's backend.
5. Test consent granted/denied, expired refresh token, revocation, webhook
  signature failure, timezone/day boundaries and account deletion.
6. Complete migration before the announced September 2026 shutdown of the
   legacy Fitbit Web API; users must explicitly re-consent to Google Health.

Health data is never used for ads, ranking, social discovery or the AI
assistant. Fitbit Air support means health summaries only.

Official references:
- https://support.google.com/googlehealth/thread/437070658/introducing-the-next-phase-of-the-fitbit-web-api
- https://support.google.com/googlehealth/answer/14237121
- https://developers.google.com/health/setup
- https://developers.google.com/health/scopes
- https://developers.google.com/health/data-types
- https://developers.google.com/health/reference/rest/v4/users.dataTypes.dataPoints/dailyRollUp
- https://developers.google.com/health/policies/health-api-developer-user-data-policy
