# Padelandia Privacy Policy

**Last updated: July 21, 2026 · Version 1.5**

This policy is provided under Articles 13-14 of Regulation (EU) 2016/679
("**GDPR**") and the Google Play and Apple App Store policies, for users of the
**Padelandia** application (the "App"). In case of discrepancy with the Italian
version, the Italian version prevails for users in Italy.

## 1. Data Controller

> ⚠️ **[COMPLETE BEFORE PUBLISHING]**
> Controller: **[Name / Company]** — **[full address]**

Privacy contact: **webnovis.info@gmail.com**

## 2. Core principle: local-first

Padelandia is built with **privacy by design and by default** (Art. 25 GDPR):
the App works 100% without an account. Matches, scores, statistics, training
logs and data read directly from HealthKit/Health Connect **stay on your
device**. The only exceptions are optional cloud features described below,
including health aggregates that a Pro user explicitly imports from an
enabled cloud provider.

## 3. Data we process

### 3.1 Data kept local by default

- Matches, scores, game events, statistics and training logs (incl. RPE and
  minutes) stay in the local database unless a Premium user enables the
  optional backup described below.
- Derived sports analytics (pressure, persistent phases, turning points and
  trends) are computed locally after a match from its event timeline. They are
  descriptive indicators with sample size and uncertainty; no health data,
  external AI or advertising profiling is involved.
- **Local health and fitness data** (steps, active calories, exercise minutes,
  in-match heart rate and, when authorized, HRV and sleep session aggregates, match workout session) from Apple Health/HealthKit,
  Apple Watch, Android Health Connect, and Wear OS Health Services, only with
  consent — see Section 6. Kept locally and never used for advertising.
- Voice scoring commands: processed by the OS speech recognizer only after an
  explicit tap; the platform may process them on-device or through its own
  service. Padelandia receives the returned text only long enough to execute the
  command; neither audio nor transcript is stored or sent to Padelandia servers.

The listed app data is stored locally and can be deleted by uninstalling the
App. Platform speech processing is governed by the device provider's settings
and privacy terms.

### 3.2 Cloud data (only with an optional account)

| Data | Purpose | Legal basis | Retention |
|---|---|---|---|
| Email, credentials (hashed) | Account management | Contract (Art. 6.1.b) | Until account deletion |
| Basic profile: name, nickname, dominant hand, role, level and privacy | Essential continuity for the free account | Contract | Until account deletion |
| Sports bio, preferred side, approximate area, club, preferred time, availability, play style and public sports statistics | Social discovery — **only if you enable "Visible on social"** | Contract + explicit opt-in | Until you disable visibility or delete the account |
| Contact requests, match proposals, team requests (incl. messages) | Matchmaking between users | Contract | Until account deletion |
| APNs token or FCM registration identifier (FID), random installation UUID, platform, app version, locale and last use | Optional delivery of social requests, invitations, coach/account updates and other operational notifications enabled by the user | Consent/affirmative action; contract for requested operational communications | Identifier until notifications are disabled, logout or account deletion; delivery audit max 30 days |
| Hashed invite tokens, attempts and anti-abuse audit | Revocable links, QR and invite codes | Contract; legitimate interest in security | Until expiry/revocation; technical audit as needed for security |
| Team image | Local display; private cloud sync only for eligible plans | Contract | Local until removal; cloud until removal or account deletion |
| Published "Wrapped" cards with public link | Voluntary sharing | Consent by voluntary publication | Until removal or account deletion |
| Structured backup (Plus/Pro/Coach): full profile, partners, teams, references to private images, matches, event timelines, training logs and portable preferences | Multi-device backup/restore | Contract | Until backup or account deletion |
| Pro Google Health connection: encrypted OAuth tokens and daily summaries (steps, active calories, active minutes, average heart rate if authorized) | User-requested fitness summary and device continuity | Contract + explicit OAuth consent | Tokens until revocation; aggregates max 30 days; all deleted on disconnect or account deletion |
| Direct Oura/WHOOP Pro connection, **only if the provider rollout is approved and enabled**: encrypted OAuth tokens and authorized sleep, HRV, readiness/recovery, strain, workout and average/resting heart-rate aggregates | User-requested fitness insights not equivalently available through the system health hub | Contract + explicit granular OAuth consent | Tokens until revocation; aggregates and transport metadata max 30 days; deletion on disconnect or account deletion |
| Pallino Assistant questions + optional match context + synthetic local context (sport profile, match aggregates, training logs/catalog, minimized team/pair stats if enabled; never system health data/email/account IDs) | AI assistant answers (Pro/Coach) | Contract | Limited answer cache; technical logs max 12 months |
| Subscription status | Premium feature delivery | Contract | Until account deletion |
| Coach marketplace data (coach profile, packages, transactions) | Coach marketplace | Contract; legal obligations | Transactions: 10 years (accounting) |

**Precise location is never collected**: the social map shows only a
user-declared indicative area and symbolic positions. No GPS is used.

Premium backups are transmitted over TLS and protected in Supabase through
authentication, Row Level Security, a size limit and a server-generated
SHA-256 integrity fingerprint. They are not end-to-end encrypted with a key
held only by the user. General backups always exclude HealthKit/Health Connect
and cloud-provider health data, authentication/OAuth tokens, billing state, device and
notification registries, permissions and local file paths. Analytics are
recomputed from matches, events and training logs to avoid inconsistent copies.

Advanced analytics run on-device only after the match. They are descriptive,
probabilistic sports indicators shown with sample size and evidence quality;
they are not federation rankings, diagnoses, guaranteed predictions or
decisions affecting the user. The engine receives no health data and makes no
calls to AI models or external services.

Remote notifications are optional and are registered only after system
permission and account sign-in. On Android, Firebase Cloud Messaging automatic
initialization stays disabled until that choice; on iOS, Padelandia requests an
APNs token only after authorization. Padelandia does not enable Firebase
Analytics or FCM BigQuery delivery export. Tokens and installation identifiers
are used only to deliver and deduplicate notifications, never for advertising,
cross-app analytics or profiling. Logout, permission withdrawal or account
deletion deactivates the registration; technical delivery outcomes are kept
for no more than 30 days for retry, security and error diagnosis.

### 3.3 Purchases

Purchases are processed by the App Store / Google Play. We receive from
**RevenueCat** (our processor) only the subscription status — **never** your
payment card data.

## 4. Recipients and processors

| Provider | Role | Location / transfer |
|---|---|---|
| **Supabase Inc.** | Database hosting, authentication, server functions | EU (project region) / USA — EU-U.S. Data Privacy Framework and SCCs |
| **RevenueCat Inc.** | Subscription status | USA — EU-U.S. Data Privacy Framework |
| **Apple Inc. / Google LLC** | Distribution, in-app payments and notification delivery through APNs/FCM | Per their own policies |
| **Google LLC — Google Health API** | Source of health data expressly authorized by a Pro user through OAuth | Google Health API Terms and applicable transfer safeguards |
| **Oura Health Oy / ŌURA** | Source of OAuth-authorized Oura aggregates, only after provider approval and direct-integration rollout | Oura API Agreement, DPA and applicable transfer safeguards to be reviewed before public rollout |
| **WHOOP, Inc.** | Source of OAuth-authorized WHOOP aggregates and signed webhook updates, only after approval and rollout | WHOOP Developer Agreement, DPA and applicable transfer safeguards to be reviewed before public rollout |
| **Server-configured LLM provider** | Pallino Assistant answers (Pro/Coach only) | See Section 7 — enable in production only after DPA, SCC/DPF and transfer review |

We do not sell personal data, do not share data with third parties for
advertising, and do not perform cross-app ad tracking.

## 6. Health and fitness data — special section

If you enable the fitness integration or record a match from a smartwatch:

- Native Apple Health/HealthKit and Android Health Connect integrations read
  only authorized data types on the phone and keep them on-device.
- On Apple Watch, during an active match and only with your consent, Padelandia
  may start a HealthKit workout session and save it to Apple Health as a
  generic workout, together with system-collected metrics during the session
  such as duration, active calories and heart rate if authorized.
- On Wear OS / Galaxy Watch, during an active match and only with granted
  permissions, Padelandia uses Health Services to manage the workout session and
  show/record local metrics such as duration, calories and heart rate when
  available.
- If you enable Workout Detection on Wear OS, the watch locally checks only
  whether Health Services reports an active exercise and its category. This is
  used to offer an optional notification, is not uploaded, and does not use
  location or heart rate to decide whether to prompt. Padelandia never opens
  itself automatically or interrupts a session owned by another app.
- On compatible Garmin devices, explicitly starting a Padelandia match may
  create a Garmin-managed Padel/Tennis FIT recording. The FIT file remains in
  the device/Garmin Connect ecosystem; Padelandia uploads scoring events, not
  the Garmin FIT file or Garmin health metrics. An existing Garmin session is
  never adopted, changed, or ended.
- If a Pro user separately connects **Google Health API**, the backend requests
  only required read scopes through OAuth and computes the **current civil
  day's** steps, active calories, active minutes, and average heart rate if
  authorized. Tokens are encrypted server-side with AES-GCM; aggregates are
  retained for no more than 30 days and are excluded from general backups.
- Disconnecting Google Health revokes the token when possible and immediately
  deletes Padelandia tokens and aggregates. Google Health data is never sent to
  the AI provider or shared for advertising.
- Direct Oura and WHOOP integrations remain disabled until approval,
  credentials and contractual review are complete. If enabled for a Pro user,
  Padelandia requests only the scopes shown on the consent screen, encrypts
  tokens with AES-GCM and stores bounded aggregates only, never raw heart-rate
  series or complete webhook payloads. Disconnecting attempts upstream
  revocation and deletes Padelandia tokens, metrics, jobs and derived summaries.
- Oura and WHOOP are not live scoring sensors. Their data may arrive only after
  the manufacturer's app syncs; Padelandia keeps direct/indirect attribution
  and avoids counting mirrored copies twice.
- It is **never** used for advertising, marketing, profiling, credit or
  insurance assessment, and never sold to data brokers (per Google Health
  Connect / Health Apps policies and Apple App Review Guideline 5.1.3).
- Permissions are granular and revocable at any time: iOS → Settings →
  Health → Data Access; Apple Watch → Health and Privacy settings; Android →
  Health Connect / app permissions; Wear OS → app permissions on the watch.
- Padelandia **does not write data to Health Connect**. On Apple Watch, it may
  write the workout session to Apple Health if you authorize HealthKit; on
  supported Garmin devices it may ask the system to save the FIT session you
  explicitly started.

Information received from Google Health, Oura or WHOOP is used only for the
visible fitness features requested by the user and under the applicable
provider terms. None of this data is sent to Pallino Assistant. In-app training logs (RPE/minutes) and synthetic team stats are not system health data and may be used by Pallino only for Pro/Coach users who have not disabled the privacy toggle.

## 7. Pallino Assistant (artificial intelligence)

The Pallino Assistant is an **AI system** (LLM); this is disclosed here and
in the App per Article 50 of Regulation (EU) 2024/1689 (the "**AI Act**").
The Free version uses only static local FAQs and content; the external AI
model is available only to Pro/Coach plans or authorized admin accounts. When
you ask Pallino Assistant a question, only the question text, the match
context you choose to attach, a concise local app context (for example role,
level, aggregate stats and suggested training) and the current conversation
history are sent to the LLM provider — **never** your health data, email or
account identity. Answers are not medical or professional advice.

You can report offensive, unsafe, incorrect or otherwise problematic AI
answers directly from the chat. The report includes the question, the answer,
the selected reason and optional details.

The app is prepared to use DeepSeek through a server-side Edge Function: the
API key stays on the server and is never included in the app. Before
production use, the controller must verify the provider contract/DPA, transfer
safeguards (SCCs, Data Privacy Framework or an equivalent legal basis),
retention periods and training opt-out options where applicable. Without that
review, the AI assistant must remain disabled or use a provider with
documented safeguards.

## 8. Security

TLS 1.2+ in transit, at-rest encryption, per-row access policies (Row Level
Security), data minimization, strong authentication on administrative access.

## 9. Your rights (Arts. 15-22 GDPR)

Access, rectification, erasure, restriction, portability, objection, and
withdrawal of consent at any time.

- **Delete account and cloud data, self-service**: App → Profile → Manage
  account → *Delete account and cloud data* (immediate and permanent), or
  follow the instructions at
  `https://<PUBLIC_RALLYMATE_DOMAIN>/account-deletion`
  ⚠️ [replace with the public HTTPS URL before publication]
- **Any other request**: **webnovis.info@gmail.com** — answered within 30
  days.

You may lodge a complaint with the Italian Data Protection Authority
(www.garanteprivacy.it) or your local EU authority.

## 10. Children

The App is not directed at children under **14**. We do not knowingly collect
data from children under 14; contact us for immediate removal if you believe
this has happened.

## 11. Automated decision-making

The matchmaking compatibility score is computed by transparent rules (level,
availability, role, style, reliability) and only orders suggestions: no
decision with legal or similarly significant effects is automated (Art. 22
GDPR).

Performance indices are likewise local, indicative statistical summaries of
the game timeline. They do not determine access, prices, rewards, sanctions or
any legal or similarly significant effect.

## 12. Changes

Material changes will be announced in the App at least 15 days in advance.
