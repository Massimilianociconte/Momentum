import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/social_service.dart';

final _socialPrivacyProvider = FutureProvider.autoDispose((ref) async {
  final auth = ref.watch(cloudAuthProvider);
  if (!auth.profileLinked) {
    return (settings: null as SocialPrivacySettings?, error: null as String?);
  }
  return ref.read(socialServiceProvider).privacySettings();
});

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy e dati')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionCard(
            title: 'DATI LOCALI',
            child: _PrivacyText(
              'Momentum funziona offline: profilo, team, partite, eventi, '
              'statistiche e allenamenti vengono salvati sul dispositivo. '
              'La partita e il punteggio sono ricostruiti dal log eventi locale.',
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'MICROFONO',
            child: _PrivacyText(
              'Il microfono viene usato solo quando tocchi il comando vocale '
              'durante una partita. Il riconoscimento è gestito dal servizio '
              'vocale del sistema; Momentum non conserva audio o trascrizioni '
              'e non c\'è ascolto continuo in background.',
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'CLOUD E ACCOUNT',
            child: _PrivacyText(
              'Account, backup, link recap, Pallino Assistant e area coach usano '
              'Supabase solo se il cloud è configurato e scegli di accedere. '
              'Il piano di abbonamento può essere sincronizzato tramite '
              'RevenueCat e gli store.',
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'NOTIFICHE',
            child: _PrivacyText(
              'Le notifiche sono facoltative. Momentum usa reminder locali e, '
              'solo dopo il consenso e l’accesso a un account, push operative '
              'per richieste social, inviti, coach e aggiornamenti importanti. '
              'Per recapitarle salva un identificativo casuale '
              'dell’installazione e il token APNs o identificativo FCM; non '
              'li usa per '
              'pubblicità o tracking e li disattiva al logout o alla revoca.',
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'SALUTE E FITNESS',
            child: _PrivacyText(
              'Le integrazioni salute sono disponibili solo per utenti Pro e '
              'restano facoltative. Su Android Momentum legge da Google Health '
              'Connect passi, calorie attive, minuti di esercizio e frequenza '
              'cardiaca media. Su iOS legge gli stessi riepiloghi da Apple '
              'Salute/HealthKit quando concedi il permesso. I permessi sono '
              'separati, revocabili dalle impostazioni di sistema e non vengono '
              'usati per pubblicità o profilazione.',
            ),
          ),
          const SizedBox(height: 12),
          const SectionCard(
            title: 'ASSISTENTE AI',
            child: _PrivacyText(
              'Pallino Assistant è disponibile solo per utenti Pro/Coach. '
              'Ogni domanda passa dalla edge function cloud (controllo piano) e '
              'al provider AI solo con: testo della domanda, cronologia chat, '
              'eventuale contesto partita, e un contesto locale sintetico '
              '(profilo sportivo, stats aggregate delle partite, catalogo e '
              'log di allenamento con RPE/minuti registrati in app, chimica '
              'team/coppie e scontri). Sono esclusi dati salute di sistema '
              '(HealthKit, Health Connect, Google Health, Oura, WHOOP), email, '
              'ID account e immagini. Puoi disattivare training/team dal '
              'toggle sotto e segnalare risposte problematiche dalla chat.',
            ),
          ),
          const SizedBox(height: 12),
          const _AssistantContextToggleCard(),
          const SizedBox(height: 12),
          const _SocialPrivacyCard(),
          const SizedBox(height: 12),
          SectionCard(
            title: 'CONTROLLO UTENTE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _PrivacyText(
                  'Puoi usare Momentum senza account. Se accedi, puoi uscire '
                  'o eliminare account e dati cloud dalla schermata Account. '
                  'La cancellazione richiede doppia conferma e rimuove i dati '
                  'cloud associati, salvo eventuali obblighi legali di '
                  'conservazione.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (CloudConfig.privacyPolicyUrl.isNotEmpty ||
              CloudConfig.termsUrl.isNotEmpty ||
              CloudConfig.deleteAccountUrl.isNotEmpty)
            SectionCard(
              title: 'DOCUMENTI E RICHIESTE',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (CloudConfig.privacyPolicyUrl.isNotEmpty)
                    _LinkChip(
                      label: 'Privacy policy',
                      url: CloudConfig.privacyPolicyUrl,
                    ),
                  if (CloudConfig.termsUrl.isNotEmpty)
                    _LinkChip(label: 'Termini', url: CloudConfig.termsUrl),
                  if (CloudConfig.deleteAccountUrl.isNotEmpty)
                    _LinkChip(
                      label: 'Eliminazione account',
                      url: CloudConfig.deleteAccountUrl,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialPrivacyCard extends ConsumerStatefulWidget {
  const _SocialPrivacyCard();

  @override
  ConsumerState<_SocialPrivacyCard> createState() => _SocialPrivacyCardState();
}

class _SocialPrivacyCardState extends ConsumerState<_SocialPrivacyCard> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(cloudAuthProvider);
    if (!auth.profileLinked) {
      return SectionCard(
        title: 'PRIVACY SOCIAL',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PrivacyText(
              'Il profilo social resta disattivato finché account e profilo '
              'locale non sono collegati. Nessun dato viene pubblicato prima '
              'della conferma.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/auth?returnTo=%2Fprivacy'),
              icon: Icon(auth.signedIn ? Icons.link : Icons.login),
              label: Text(auth.signedIn ? 'Collega profilo' : 'Accedi'),
            ),
          ],
        ),
      );
    }

    final async = ref.watch(_socialPrivacyProvider);
    return SectionCard(
      title: 'PRIVACY SOCIAL',
      child: async.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (error, _) => _PrivacyRetry(
          message: '$error',
          onRetry: () => ref.invalidate(_socialPrivacyProvider),
        ),
        data: (result) {
          final settings = result.settings;
          if (settings == null) {
            return _PrivacyRetry(
              message: result.error ?? 'Preferenze non disponibili.',
              onRetry: () => ref.invalidate(_socialPrivacyProvider),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.socialEnabled,
                onChanged: _busy
                    ? null
                    : (value) => _save(
                        settings.copyWith(
                          socialEnabled: value,
                          mapVisibility: value
                              ? (settings.mapVisibility == 'HIDDEN'
                                    ? 'PUBLIC'
                                    : settings.mapVisibility)
                              : settings.mapVisibility,
                        ),
                      ),
                title: const Text('Partecipa al social'),
                subtitle: const Text(
                  'Disattivando sparisci da ricerca e mappa.',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'CHI PUÒ TROVARTI',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    ('PUBLIC', 'Tutti', Icons.public),
                    ('FRIENDS', 'Amici', Icons.people_outline),
                    ('HIDDEN', 'Nessuno', Icons.visibility_off_outlined),
                  ])
                    ChoiceChip(
                      avatar: Icon(option.$3, size: 17),
                      label: Text(option.$2),
                      selected: settings.mapVisibility == option.$1,
                      onSelected: _busy || !settings.socialEnabled
                          ? null
                          : (_) => _save(
                              settings.copyWith(mapVisibility: option.$1),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const _PrivacyText(
                'Momentum usa solo la zona scelta nel profilo. Coordinate '
                'precise, seriali e identificativi hardware non sono pubblicati.',
              ),
              const Divider(height: 24),
              _PrivacyToggle(
                value: settings.showOnlineStatus,
                title: 'Mostra stato online',
                subtitle: 'Indica attività recente, non l’ora esatta.',
                enabled: !_busy && settings.socialEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(showOnlineStatus: value)),
              ),
              _PrivacyToggle(
                value: settings.showActivity,
                title: 'Mostra ultima attività',
                subtitle: 'Condividi quando hai usato di recente Momentum.',
                enabled: !_busy && settings.socialEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(showActivity: value)),
              ),
              _PrivacyToggle(
                value: settings.showClub,
                title: 'Mostra centro padel',
                subtitle: 'Pubblica solo il club inserito volontariamente.',
                enabled: !_busy && settings.socialEnabled,
                onChanged: (value) => _save(settings.copyWith(showClub: value)),
              ),
              _PrivacyToggle(
                value: settings.publicStatsEnabled,
                title: 'Mostra statistiche sportive',
                subtitle: 'Partite, win rate e badge; mai dati salute.',
                enabled: !_busy && settings.socialEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(publicStatsEnabled: value)),
              ),
              if (_busy) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(SocialPrivacySettings settings) async {
    setState(() => _busy = true);
    final error = await ref
        .read(socialServiceProvider)
        .updatePrivacySettings(settings);
    if (error == null) {
      await ref
          .read(keyValueRepoProvider)
          .set('social_enabled', settings.socialEnabled ? 'true' : 'false');
      ref.invalidate(_socialPrivacyProvider);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// Opt-in/out for sending synthetic training + team context to Pallino.
class _AssistantContextToggleCard extends ConsumerWidget {
  const _AssistantContextToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(assistantShareTrainingTeamProvider).value ?? true;
    return SectionCard(
      title: 'CONTESTO PALLINO',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: share,
        onChanged: (v) async {
          await ref
              .read(keyValueRepoProvider)
              .set('assistant_share_training_team', v ? '1' : '0');
        },
        title: const Text('Includi allenamenti e team'),
        subtitle: const Text(
          'Se attivo, Pallino riceve riassunti sportivi di training e '
          'coppie/team (non dati salute di sistema). Se disattivo, restano '
          'solo profilo e form partite aggregate.',
          style: TextStyle(fontSize: 12.5, height: 1.35),
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    value: value,
    onChanged: enabled ? onChanged : null,
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

class _PrivacyRetry extends StatelessWidget {
  const _PrivacyRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(onPressed: onRetry, child: const Text('Riprova')),
    ],
  );
}

class _PrivacyText extends StatelessWidget {
  const _PrivacyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 13),
  );
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.open_in_new, size: 16),
      onPressed: () async {
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link non apribile. Riprova.')),
          );
        }
      },
    );
  }
}
