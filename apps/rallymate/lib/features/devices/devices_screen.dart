library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../domain/health_provider.dart';
import '../../services/health_connect.dart';
import '../../services/health_provider_catalog.dart';
import '../../services/watch_sync.dart';
import '../../services/workout_detection_preferences.dart';
import '../../services/wearable_cloud_sync.dart';
import '../../services/wearable_provider_service.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(connectedDevicesProvider);
    final live = ref.watch(watchSyncProvider);
    final registeredProviders = devices.maybeWhen(
      data: (items) => items.map(_providerFrom).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salute e dispositivi'),
        leading: const SafeBackButton(fallback: AppLocations.profile),
        actions: [
          IconButton(
            onPressed: () => _refreshProviders(context, ref),
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna stato',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshProviders(context, ref, quiet: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const _HealthDetectionBanner(),
            const SizedBox(height: 12),
            const _SectionEyebrow(
              icon: Icons.sports_tennis,
              title: 'SMARTWATCH PER IL PUNTEGGIO',
              subtitle:
                  'Companion native che creano partite, segnano punti e '
                  'funzionano offline.',
            ),
            const SizedBox(height: 10),
            _ConnectionSummary(state: live),
            const SizedBox(height: 12),
            _WorkoutDetectionCard(
              platformLabel: live.platformLabel,
              registeredProviders: registeredProviders,
            ),
            const SizedBox(height: 12),
            devices.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (error, _) => SectionCard(
                child: Text('Registro dispositivi non disponibile: $error'),
              ),
              data: (items) {
                final scoringItems = items
                    .where(
                      (device) => !const {
                        'GOOGLE_HEALTH',
                        'OURA_DIRECT',
                        'WHOOP_DIRECT',
                        'TIZEN_RETIRED',
                      }.contains(_providerFrom(device)),
                    )
                    .toList(growable: false);
                return scoringItems.isEmpty
                    ? EmptyStateCard(
                        icon: Icons.watch_outlined,
                        title: 'Collega il tuo smartwatch',
                        message:
                            'Una guida controlla companion, comunicazione e '
                            'scoring senza raccogliere seriali o indirizzi hardware.',
                        primaryLabel: 'Configura smartwatch',
                        primaryIcon: Icons.arrow_forward,
                        onPrimary: () => context.push('/devices/setup'),
                      )
                    : Column(
                        children: [
                          for (final device in scoringItems) ...[
                            _DeviceCard(device: device),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/devices/setup'),
              icon: const Icon(Icons.add),
              label: const Text('Configura o verifica un watch'),
            ),
            const SizedBox(height: 24),
            const _SectionEyebrow(
              icon: Icons.health_and_safety_outlined,
              title: 'SALUTE, RECUPERO E SENSORI',
              subtitle:
                  'Hub di sistema, provider autorizzati e sensori live. '
                  'Queste fonti non possono segnare punti.',
            ),
            const SizedBox(height: 10),
            _HealthProvidersSection(registeredProviders: registeredProviders),
            const SizedBox(height: 12),
            const SectionCard(
              title: 'PRIVACY DISPOSITIVO',
              child: Text(
                'Padelandia non salva seriali o identificativi pubblicitari. '
                'Gli identificativi Garmin e BLE restano sul telefono. I '
                'token OAuth cloud sono cifrati sul server e i dati salute '
                'vengono importati soltanto dopo consenso esplicito.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clear active / inactive / unauthorized state for automatic health import.
class _HealthDetectionBanner extends ConsumerWidget {
  const _HealthDetectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(healthConnectStatusProvider);
    final sources = ref.watch(healthDataSourcesProvider).value ?? const [];
    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        final hubName = HealthConnectService.providerName;
        final (:color, :icon, :title, :body, :actionLabel) = _healthBannerCopy(
          status: status,
          hubName: hubName,
          hasImportedSources: sources.isNotEmpty,
        );
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  HealthConnectService.isApple
                      ? '/devices/health/APPLE_HEALTH'
                      : '/devices/health/HEALTH_CONNECT',
                ),
                icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}

({
  Color color,
  IconData icon,
  String title,
  String body,
  String actionLabel,
}) _healthBannerCopy({
  required HealthConnectStatus status,
  required String hubName,
  required bool hasImportedSources,
}) {
  if (!status.available) {
    return (
      color: Colors.white54,
      icon: Icons.health_and_safety_outlined,
      title: '$hubName non disponibile',
      body:
          'Su questo dispositivo non è possibile importare automaticamente i '
          'dati salute. Padelandia continua a registrare le partite in locale.',
      actionLabel: 'Dettagli integrazione',
    );
  }
  if (!status.granted) {
    return (
      color: const Color(0xFFFFB74D),
      icon: Icons.lock_outline,
      title: 'Rilevamento automatico non autorizzato',
      body:
          'Concedi i permessi a $hubName per importare passi, calorie e '
          'frequenza cardiaca e associarli alle partite. La registrazione '
          'locale resta sempre attiva.',
      actionLabel: 'Autorizza $hubName',
    );
  }
  if (hasImportedSources) {
    return (
      color: RallyColors.win,
      icon: Icons.sensors,
      title: 'Rilevamento automatico attivo',
      body:
          'I dati da $hubName vengono sincronizzati e collegati alle partite '
          'con deduplica. La partita resta la fonte primaria; i dati salute '
          'la arricchiscono senza sovrascrivere lo score.',
      actionLabel: 'Gestisci permessi e sorgenti',
    );
  }
  return (
    color: RallyColors.lime,
    icon: Icons.sync_problem,
    title: 'Autorizzato, in attesa di dati',
    body:
        'I permessi di $hubName sono attivi ma non risultano ancora metriche '
        'importate. Completa un allenamento o avvia una sincronizzazione '
        'manuale dalla scheda provider.',
    actionLabel: 'Apri $hubName',
  );
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: RallyColors.lime),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white38,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HealthProvidersSection extends ConsumerWidget {
  const _HealthProvidersSection({required this.registeredProviders});
  final Set<String> registeredProviders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(healthProviderCatalogProvider);
    final sources = ref.watch(healthDataSourcesProvider).value ?? const [];
    return catalog.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) =>
          SectionCard(child: Text('Catalogo salute non disponibile: $error')),
      data: (value) {
        final providers = value.forCurrentPhone(includeInternal: kDebugMode);
        if (providers.isEmpty) {
          return const SectionCard(
            child: Text('Nessuna integrazione salute disponibile.'),
          );
        }
        return Column(
          children: [
            for (final provider in providers) ...[
              _HealthProviderTile(
                provider: provider,
                detected: sources.any(
                  (source) =>
                      _healthSourceMatches(provider.id, source.provider),
                ),
                registered: registeredProviders.contains(provider.id),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _HealthProviderTile extends StatelessWidget {
  const _HealthProviderTile({
    required this.provider,
    required this.detected,
    required this.registered,
  });

  final HealthProviderDescriptor provider;
  final bool detected;
  final bool registered;

  @override
  Widget build(BuildContext context) {
    final active = detected || registered;
    return SectionCard(
      child: InkWell(
        onTap: () => context.push('/devices/health/${provider.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? RallyColors.win.withValues(alpha: 0.12)
                      : RallyColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _healthProviderIcon(provider),
                  color: active ? RallyColors.win : RallyColors.training,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (provider.requiresPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.workspace_premium,
                            size: 15,
                            color: RallyColors.lime,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? 'Origine rilevata · ${_healthSupportCopy(provider.support)}'
                          : _healthSupportCopy(provider.support),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

bool _healthSourceMatches(String providerId, String sourceProvider) =>
    providerId == sourceProvider ||
    (providerId == 'HELIO_STRAP_HEALTH_HUB' &&
        sourceProvider == 'ZEPP_HEALTH_HUB');

String _healthSupportCopy(HealthProviderSupportStatus status) =>
    switch (status) {
      HealthProviderSupportStatus.production => 'Supporto completo',
      HealthProviderSupportStatus.beta => 'Beta controllata',
      HealthProviderSupportStatus.indirect => 'Import tramite hub salute',
      HealthProviderSupportStatus.experimental => 'Sperimentale',
      HealthProviderSupportStatus.internal => 'Test interno',
      HealthProviderSupportStatus.research => 'In valutazione',
      HealthProviderSupportStatus.notSupported => 'Non supportato',
    };

IconData _healthProviderIcon(HealthProviderDescriptor provider) =>
    switch (provider.category) {
      HealthProviderCategory.systemHub => Icons.health_and_safety_outlined,
      HealthProviderCategory.cloudProvider => Icons.cloud_sync_outlined,
      HealthProviderCategory.liveSensor => Icons.monitor_heart_outlined,
      HealthProviderCategory.scoringWearable => Icons.watch_outlined,
      HealthProviderCategory.indirectSource => Icons.radar,
    };

class _WorkoutDetectionCard extends ConsumerWidget {
  const _WorkoutDetectionCard({
    required this.platformLabel,
    required this.registeredProviders,
  });

  final String platformLabel;
  final Set<String> registeredProviders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(workoutDetectionPreferencesProvider);
    final controller = ref.read(workoutDetectionPreferencesProvider.notifier);
    final supportsLiveDetection = platformLabel == 'Wear OS';
    final explanations = <String>[
      if (platformLabel == 'Wear OS')
        'Wear OS 3+: notifica un esercizio esterno esposto da Health Services, '
            'senza aprire automaticamente Padelandia.',
      if (platformLabel == 'Apple Watch')
        'Apple Watch: le sessioni esterne non sono intercettabili live; Avvio '
            'rapido e Siri avviano la sessione Salute di Padelandia.',
      if (registeredProviders.contains('GARMIN_CONNECT_IQ'))
        'Garmin: nessun trigger esterno pubblico; avviando il match Padelandia '
            'registra una propria attività FIT Padel sui modelli compatibili.',
      if (registeredProviders.contains('FITBIT_OS'))
        'Fitbit OS: avvio manuale dall’app legacy; nessun callback pubblico '
            'per un allenamento iniziato altrove.',
      if (registeredProviders.contains('GOOGLE_HEALTH'))
        'Fitbit Air / Google Health: rilevamento solo differito sul telefono, '
            'senza prompt o UI sul wearable.',
      if (platformLabel.isEmpty && registeredProviders.isEmpty)
        'Il trigger in tempo reale è disponibile soltanto su Wear OS 3+ e solo '
            'quando l’app sorgente pubblica l’esercizio in Health Services.',
    ];

    return SectionCard(
      title: 'RILEVAMENTO ALLENAMENTO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final explanation in explanations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                explanation,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          if (!supportsLiveDetection)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Le opzioni automatiche restano disattivate perché questa '
                'piattaforma non espone un trigger live pubblico.',
                style: TextStyle(
                  color: RallyColors.training,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkoutDetectionMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: WorkoutDetectionMode.off,
                  icon: Icon(Icons.notifications_off_outlined),
                  label: Text('Off'),
                ),
                ButtonSegment(
                  value: WorkoutDetectionMode.ask,
                  icon: Icon(Icons.notifications_active_outlined),
                  label: Text('Chiedi'),
                ),
                ButtonSegment(
                  value: WorkoutDetectionMode.quickStart,
                  icon: Icon(Icons.bolt),
                  label: Text('Rapido'),
                ),
              ],
              selected: {preferences.mode},
              onSelectionChanged: supportsLiveDetection
                  ? (selection) {
                      if (selection.isNotEmpty) {
                        controller.setMode(selection.first);
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            value: preferences.racketSportsOnly,
            onChanged: supportsLiveDetection && preferences.enabled
                ? controller.setRacketSportsOnly
                : null,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Solo sport di racchetta',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Tennis, badminton, squash, racquetball e tennistavolo. '
              'Il sistema non espone ancora una categoria padel dedicata.',
              style: TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ),
          const Divider(height: 16),
          const ListTile(
            enabled: false,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.watch_outlined),
            title: Text('Solo quando indosso lo smartwatch'),
            subtitle: Text(
              'Non disponibile: nessun segnale pubblico è abbastanza '
              'affidabile e uniforme tra i provider supportati.',
            ),
          ),
          Text(
            !supportsLiveDetection
                ? 'Su Apple Watch, Garmin e Fitbit l’avvio rapido resta '
                      'disponibile dall’app, shortcut o menu supportato.'
                : preferences.mode == WorkoutDetectionMode.quickStart
                ? '“Rapido” prepara l’ultimo formato come azione principale, '
                      'ma richiede sempre un tocco esplicito.'
                : 'Le preferenze restano sul telefono e sul watch. Nessuna '
                      'posizione, frequenza cardiaca o cronologia viene usata '
                      'per decidere il prompt.',
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.white54,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSummary extends ConsumerWidget {
  const _ConnectionSummary({required this.state});

  final WatchSyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _statusCopy(state.status);
    final detail = _connectionDetail(state);
    return SectionCard(
      title: 'APPLE WATCH E WEAR OS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.color.withValues(alpha: 0.14),
                ),
                child: Icon(status.icon, color: status.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.platformLabel.isEmpty
                          ? 'Verifica la piattaforma con la guida.'
                          : state.deviceName.isEmpty
                          ? state.platformLabel
                          : '${state.platformLabel} · ${state.deviceName}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: state.ready || state.reachable
                    ? () async {
                        final ok = await ref
                            .read(watchSyncProvider.notifier)
                            .testConnection();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Segnale ricevuto: il watch ha vibrato.'
                                  : 'Il watch non ha confermato il segnale.',
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.wifi_tethering),
                tooltip: 'Test connessione',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CompanionCapabilityRow(
            label: 'Watch associato',
            ok: state.paired,
            missing: 'Nessun dispositivo associato al telefono',
          ),
          _CompanionCapabilityRow(
            label: 'Companion installata',
            ok: state.companionInstalled,
            missing: 'Installa Padelandia sul watch',
          ),
          _CompanionCapabilityRow(
            label: 'Connessione live',
            ok: state.reachable,
            missing: 'Watch momentaneamente non raggiungibile',
          ),
          _CompanionCapabilityRow(
            label: 'Sincronizzazione',
            ok: state.ready,
            missing: detail,
          ),
        ],
      ),
    );
  }
}

class _CompanionCapabilityRow extends StatelessWidget {
  const _CompanionCapabilityRow({
    required this.label,
    required this.ok,
    required this.missing,
  });

  final String label;
  final bool ok;
  final String missing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? RallyColors.win : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok ? label : '$label · $missing',
              style: TextStyle(
                fontSize: 12,
                color: ok ? Colors.white70 : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _connectionDetail(WatchSyncState state) {
  if (!state.paired) return 'Associa un Apple Watch o un Wear OS';
  if (!state.companionInstalled) return 'Apri l’App Store del watch e installa Padelandia';
  if (!state.reachable) {
    return 'La partita può comunque essere accodata; alza il polso o apri l’app';
  }
  return 'Pronto a inviare partite e ricevere punti';
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.device});

  final ConnectedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _providerFrom(device);
    final status = _statusCopy(device.status, provider: provider);
    final name = device.alias.isNotEmpty
        ? device.alias
        : device.displayName.isNotEmpty
        ? device.displayName
        : device.platform;
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.watch, color: status.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (device.isDefault) ...[
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.star,
                            size: 15,
                            color: RallyColors.lime,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${device.family.isEmpty ? provider : device.family} · ${status.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Azioni dispositivo',
                onSelected: (action) => _handle(context, ref, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                  PopupMenuItem(value: 'default', child: Text('Predefinito')),
                  PopupMenuItem(value: 'setup', child: Text('Ripeti verifica')),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Scollega da Padelandia'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  label: 'Ultimo contatto',
                  value: _date(device.lastSeenAtMs),
                ),
              ),
              Expanded(
                child: _Meta(
                  label: 'Ultima sync',
                  value: _date(device.lastSyncAtMs),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(connectedDeviceRepoProvider);
    switch (action) {
      case 'rename':
        final controller = TextEditingController(text: device.alias);
        final value = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Nome del dispositivo'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Nome locale'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Salva'),
              ),
            ],
          ),
        );
        if (value != null) await repo.rename(device.id, value);
        return;
      case 'default':
        await repo.setDefault(device.id);
        return;
      case 'setup':
        if (context.mounted) context.push('/devices/setup');
        return;
      case 'remove':
        final provider = _providerFrom(device);
        final revokesCloud = const {
          'GARMIN_CONNECT_IQ',
          'FITBIT_OS',
          'GOOGLE_HEALTH',
        }.contains(provider);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Scollegare da Padelandia?'),
            content: Text(
              revokesCloud
                  ? 'Revoca prima token e accesso sul server Padelandia, poi '
                        'rimuove la configurazione locale. Il pairing di '
                        'sistema resta invariato.'
                  : 'Rimuove la configurazione locale. Il pairing di sistema '
                        'resta invariato e potrai configurarlo di nuovo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Scollega'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          if (revokesCloud) {
            await ref
                .read(wearableProviderServiceProvider)
                .disconnect(provider);
          }
          await repo.remove(device.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dispositivo scollegato.')),
            );
          }
        } on WearableProviderException catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${error.message} La configurazione locale non è stata rimossa.',
              ),
            ),
          );
        }
        return;
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

({String label, Color color, IconData icon}) _statusCopy(
  String status, {
  String? provider,
}) {
  // Health-only providers must never look match-ready.
  if (provider == 'GOOGLE_HEALTH' &&
      (status == 'READY' || status == 'CONNECTED' || status == 'HEALTH_SYNCED')) {
    return (
      label: 'Collegato · solo salute',
      color: RallyColors.lime,
      icon: Icons.favorite_outline,
    );
  }
  return switch (status) {
    'READY' => (
      label: 'Pronto per la partita',
      color: RallyColors.win,
      icon: Icons.check_circle_outline,
    ),
    'CONNECTED' => (
      label: 'Associato · verifica scoring incompleta',
      color: RallyColors.lime,
      icon: Icons.link,
    ),
    'HEALTH_SYNCED' => (
      label: 'Dati salute sincronizzati',
      color: RallyColors.lime,
      icon: Icons.favorite_outline,
    ),
    'NOT_PAIRED' => (
      label: 'Nessun watch associato',
      color: Colors.white54,
      icon: Icons.watch_off_outlined,
    ),
    'COMPANION_MISSING' => (
      label: 'Companion app non installata',
      color: const Color(0xFFFFB74D),
      icon: Icons.system_update_alt,
    ),
    'PERMISSIONS_INCOMPLETE' => (
      label: 'Permessi incompleti',
      color: const Color(0xFFFFB74D),
      icon: Icons.admin_panel_settings_outlined,
    ),
    'SYNC_PENDING' => (
      label: 'Sincronizzazione in corso',
      color: RallyColors.lime,
      icon: Icons.sync,
    ),
    'UNSUPPORTED' => (
      label: 'Piattaforma non supportata',
      color: const Color(0xFFFFB74D),
      icon: Icons.do_not_disturb_alt_outlined,
    ),
    'REVOKED' || 'DISCONNECTED' => (
      label: 'Scollegato',
      color: Colors.white54,
      icon: Icons.link_off,
    ),
    'NOT_REACHABLE' => (
      label: 'Momentaneamente non raggiungibile',
      color: const Color(0xFFFFB74D),
      icon: Icons.signal_wifi_statusbar_connected_no_internet_4,
    ),
    'CHECKING' => (
      label: 'Verifica in corso…',
      color: RallyColors.lime,
      icon: Icons.hourglass_top,
    ),
    _ => (
      label: 'Stato sconosciuto',
      color: Colors.white54,
      icon: Icons.help_outline,
    ),
  };
}

String _date(int? milliseconds) {
  if (milliseconds == null) return 'Mai';
  return DateFormat(
    'dd/MM · HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal());
}

String _providerFrom(ConnectedDevice device) {
  try {
    final value = jsonDecode(device.capabilitiesJson);
    if (value is Map && value['provider'] is String) {
      return value['provider'] as String;
    }
  } catch (_) {
    // Legacy local records use platform as their provider identifier.
  }
  return device.platform;
}

Future<void> _refreshProviders(
  BuildContext context,
  WidgetRef ref, {
  bool quiet = false,
}) async {
  final errors = <String>[];
  final repo = ref.read(connectedDeviceRepoProvider);
  final providers = ref.read(wearableProviderServiceProvider);
  await ref.read(watchSyncProvider.notifier).refresh();
  final devices = await repo.all();

  for (final device in devices) {
    final provider = _providerFrom(device);
    try {
      switch (provider) {
        case 'GARMIN_CONNECT_IQ':
          final status = await providers.garminStatus();
          final known = await providers.garminDevices();
          final expectedId = device.id.replaceFirst('watch_garmin_', '');
          final target = known
              .where((item) => item.deviceId == expectedId)
              .firstOrNull;
          final radioConnected =
              status['sdkReady'] == true && target?.connected == true;
          // READY only after a successful ping on the registered device.
          var ready = false;
          if (radioConnected && target != null) {
            ready = await providers.testGarmin(target.nativeId);
          }
          final synced = ready
              ? await providers.syncGarminQueue(
                  commitEventsToPhone: (events) async {
                    await ref
                        .read(wearableCloudSyncProvider)
                        .commitGarminEvents(events);
                  },
                )
              : 0;
          await repo.updateConnectionState(
            device.id,
            status: ready ? 'READY' : 'NOT_REACHABLE',
            markSeen: radioConnected,
            markSynced: ready && synced > 0,
          );
        case 'FITBIT_OS':
          final info = await providers.fitbitConnectionInfo();
          // Never auto-promote CONNECTED → READY: READY requires setup proof
          // (punto di prova). Refresh only preserves READY when token is live.
          final nextStatus = !info.isPairedLive
              ? (info.status == 'CONNECTED' ? 'NOT_REACHABLE' : info.status)
              : (device.status == 'READY' ? 'READY' : 'CONNECTED');
          await repo.updateConnectionState(
            device.id,
            status: nextStatus,
            markSeen: info.isPairedLive,
          );
        case 'GOOGLE_HEALTH':
          final status = await providers.googleHealthStatus();
          if (status.connected) await providers.syncGoogleHealthToday();
          await repo.updateConnectionState(
            device.id,
            // Health-only: never READY / never "Pronto per la partita".
            status: status.connected ? 'CONNECTED' : status.status,
            markSeen: status.connected,
            markSynced: status.connected,
          );
        case 'TIZEN_RETIRED':
          await repo.updateConnectionState(
            device.id,
            status: 'UNSUPPORTED',
            markSeen: false,
          );
      }
    } on WearableProviderException catch (error) {
      errors.add(error.message);
    } catch (_) {
      errors.add('Impossibile aggiornare ${device.displayName}.');
    }
  }

  if (devices.any(
    (device) => const {
      'GARMIN_CONNECT_IQ',
      'FITBIT_OS',
    }.contains(_providerFrom(device)),
  )) {
    try {
      await ref.read(wearableCloudSyncProvider).sync();
    } on WearableProviderException catch (error) {
      errors.add(error.message);
    } catch (_) {
      errors.add('La coda wearable non è stata sincronizzata.');
    }
  }

  if (!quiet && errors.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errors.toSet().join(' '))));
  }
}
