library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../domain/entitlements.dart';
import '../../domain/health_provider.dart';
import '../../services/ble_heart_rate.dart';
import '../../services/health_provider_catalog.dart';
import '../../services/wearable_provider_service.dart';

class HealthProviderSetupScreen extends ConsumerStatefulWidget {
  const HealthProviderSetupScreen({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<HealthProviderSetupScreen> createState() =>
      _HealthProviderSetupScreenState();
}

class _HealthProviderSetupScreenState
    extends ConsumerState<HealthProviderSetupScreen> {
  bool _busy = false;
  String _state = 'LOADING';
  String? _message;
  DateTime? _lastSyncAt;
  List<BleHeartRateDevice> _bleDevices = const [];
  bool _scanningBle = false;
  BleHeartRateMeasurement? _latestMeasurement;
  String? _connectedBleIdentifier;
  String? _selectedBleIdentifier;
  String? _connectingBleIdentifier;
  StreamSubscription<BleHeartRateMeasurement>? _heartSubscription;
  StreamSubscription<BleHeartRateStatus>? _bleStatusSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.providerId == 'BLE_HEART_RATE') {
      final ble = ref.read(bleHeartRateServiceProvider);
      _heartSubscription = ble.measurements.listen((value) {
        if (mounted) setState(() => _latestMeasurement = value);
      });
      _bleStatusSubscription = ble.statusChanges.listen((value) {
        if (!mounted) return;
        setState(() {
          // Do not wipe ERROR chrome on a false connectionChanged after fail.
          if (value.connected) {
            _state = 'CONNECTED';
            _connectedBleIdentifier = value.identifier;
            _selectedBleIdentifier = value.identifier;
          } else if (_state != 'ERROR') {
            _state = 'AVAILABLE';
            _connectedBleIdentifier = null;
          } else {
            _connectedBleIdentifier = null;
          }
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _heartSubscription?.cancel();
    _bleStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(healthProviderCatalogProvider);
    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: _appBar(context, 'Salute e dispositivi'),
        body: Center(child: Text('Configurazione non disponibile: $error')),
      ),
      data: (value) {
        final descriptor = value.byId(widget.providerId);
        if (descriptor == null) {
          return Scaffold(
            appBar: _appBar(context, 'Salute e dispositivi'),
            body: const Center(child: Text('Provider non riconosciuto.')),
          );
        }
        if (!descriptor.isEnabled ||
            descriptor.support == HealthProviderSupportStatus.research ||
            descriptor.support == HealthProviderSupportStatus.notSupported) {
          return Scaffold(
            appBar: _appBar(context, 'Salute e dispositivi'),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Questa integrazione non è ancora disponibile. Non è '
                  'necessaria alcuna configurazione sul dispositivo.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _buildProvider(context, descriptor);
      },
    );
  }

  Widget _buildProvider(
    BuildContext context,
    HealthProviderDescriptor descriptor,
  ) {
    final sources = ref.watch(healthDataSourcesProvider).value ?? const [];
    final matching = sources
        .where((source) => _matchesSource(descriptor.id, source.provider))
        .toList(growable: false);
    final entitlements = ref.watch(entitlementsProvider);
    final premiumLocked =
        descriptor.requiresPremium && !entitlements.healthConnectSync;
    final connected =
        descriptor.category == HealthProviderCategory.indirectSource
        ? matching.isNotEmpty
        : _state == 'CONNECTED';
    return Scaffold(
      appBar: _appBar(context, descriptor.displayName),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProviderHero(descriptor: descriptor, connected: connected),
            const SizedBox(height: 12),
            _CapabilityCard(descriptor: descriptor),
            const SizedBox(height: 12),
            if (premiumLocked)
              _PremiumHealthCard(
                onUpgrade: () {
                  pushPaywall(
                    context,
                    gate: 'health_connect',
                    plan: Plan.pro,
                    reason: gates['health_connect']?.pitch,
                  );
                },
              )
            else if (descriptor.category == HealthProviderCategory.liveSensor)
              _buildBleSetup(descriptor)
            else
              _buildConnectionSteps(descriptor, connected),
            if (_message case final message?) ...[
              const SizedBox(height: 12),
              _InlineStatus(message: message, isError: _state == 'ERROR'),
              if (_state == 'ERROR' &&
                  descriptor.category == HealthProviderCategory.liveSensor) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final opened = await ref
                        .read(bleHeartRateServiceProvider)
                        .openAppSettings();
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Apri manualmente Impostazioni → Momentum → Bluetooth.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Apri impostazioni app'),
                ),
              ],
            ],
            if (matching.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetectedSourcesCard(sources: matching),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: 'PRIVACY E DATI',
              child: Text(
                _privacyCopy(descriptor),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => launchUrl(
                descriptor.sourceUrl,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Documentazione ufficiale'),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context, String title) => AppBar(
    leading: IconButton(
      tooltip: 'Torna a Salute e dispositivi',
      onPressed: () =>
          context.canPop() ? context.pop() : context.go('/devices'),
      icon: const Icon(Icons.arrow_back),
    ),
    title: Text(title),
  );

  Widget _buildConnectionSteps(
    HealthProviderDescriptor descriptor,
    bool connected,
  ) {
    final indirect =
        descriptor.category == HealthProviderCategory.indirectSource;
    final system = descriptor.category == HealthProviderCategory.systemHub;
    final cloud = descriptor.category == HealthProviderCategory.cloudProvider;
    final steps = indirect
        ? const [
            'Apri l’app del dispositivo e abilita l’esportazione salute.',
            'Concedi a Momentum soltanto le categorie che vuoi importare.',
            'Torna qui e verifica l’origine dei dati.',
          ]
        : system
        ? const [
            'Leggi l’informativa e scegli le categorie salute.',
            'Concedi i permessi nel pannello di sistema.',
            'Importa il riepilogo della giornata corrente.',
          ]
        : const [
            'Accedi sul sito ufficiale del provider.',
            'Conferma solo gli ambiti mostrati nella schermata di consenso.',
            'Torna in Momentum e avvia la prima sincronizzazione.',
          ];
    return SectionCard(
      title: 'CONFIGURAZIONE GUIDATA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < steps.length; index++)
            _SetupStep(index: index + 1, text: steps[index]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _primaryAction(descriptor),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(connected ? Icons.sync : Icons.link),
              label: Text(
                connected
                    ? 'Aggiorna dati'
                    : indirect
                    ? 'Verifica origine dati'
                    : cloud
                    ? 'Collega account'
                    : 'Concedi accesso',
              ),
            ),
          ),
          if (connected && cloud) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _disconnect(descriptor),
                icon: const Icon(Icons.link_off),
                label: const Text('Scollega e cancella dati importati'),
              ),
            ),
          ] else if (connected && (system || indirect)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _deleteLocalHealthData(descriptor),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Rimuovi i dati importati'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Per revocare anche l’accesso, usa le impostazioni Apple Salute '
              'o Health Connect del telefono.',
              style: TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
          if (_lastSyncAt case final value?) ...[
            const SizedBox(height: 10),
            Text(
              'Ultimo aggiornamento: ${_formatDate(value)}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBleSetup(HealthProviderDescriptor descriptor) {
    final bleInteractionBusy = _scanningBle || _connectingBleIdentifier != null;
    BleHeartRateDevice? selectedDevice;
    for (final device in _bleDevices) {
      if (device.identifier == _selectedBleIdentifier) {
        selectedDevice = device;
        break;
      }
    }
    return SectionCard(
      title: 'ASSOCIA SENSORE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indossa e attiva il sensore. Momentum cerca solo dispositivi '
            'che pubblicano il servizio cardiaco Bluetooth standard.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy || bleInteractionBusy ? null : _scanBle,
              icon: _scanningBle
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: const Text('Cerca sensori cardiaci'),
            ),
          ),
          if (_bleDevices.isNotEmpty) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SENSORI TROVATI',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_bleDevices.length}',
                  style: const TextStyle(
                    color: RallyColors.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final device in _bleDevices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BleHeartRateDeviceTile(
                  key: ValueKey('ble-device-${device.identifier}'),
                  device: device,
                  isSelected: _selectedBleIdentifier == device.identifier,
                  isConnecting: _connectingBleIdentifier == device.identifier,
                  isConnected:
                      _connectedBleIdentifier == device.identifier &&
                      _state == 'CONNECTED',
                  onSelect: _busy || bleInteractionBusy
                      ? null
                      : () => setState(
                          () => _selectedBleIdentifier = device.identifier,
                        ),
                  onConnect:
                      _busy ||
                          bleInteractionBusy ||
                          _selectedBleIdentifier != device.identifier ||
                          (_connectedBleIdentifier == device.identifier &&
                              _state == 'CONNECTED')
                      ? null
                      : () => _connectBle(device),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _busy ||
                        bleInteractionBusy ||
                        selectedDevice == null ||
                        (_connectedBleIdentifier == selectedDevice.identifier &&
                            _state == 'CONNECTED')
                    ? null
                    : () => _connectBle(selectedDevice!),
                icon: _connectingBleIdentifier != null
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_connected),
                label: Text(
                  selectedDevice == null
                      ? 'Seleziona un sensore'
                      : _connectedBleIdentifier == selectedDevice.identifier &&
                            _state == 'CONNECTED'
                      ? 'Sensore collegato'
                      : 'Collega sensore',
                ),
              ),
            ),
          ],
          if (_latestMeasurement case final measurement?) ...[
            const Divider(height: 28),
            Semantics(
              liveRegion: true,
              label: '${measurement.bpm} battiti al minuto',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: RallyColors.loss),
                  const SizedBox(width: 8),
                  Text(
                    '${measurement.bpm} bpm',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_state == 'CONNECTED') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _disconnectBle,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Scollega sensore'),
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _forgetBle,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Dimentica sensore e dati locali'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh({bool preserveMessage = false}) async {
    final catalog = await ref.read(healthProviderCatalogProvider.future);
    final descriptor = catalog.byId(widget.providerId);
    if (descriptor == null || !mounted) return;
    try {
      String state;
      DateTime? lastSync;
      if (descriptor.category == HealthProviderCategory.indirectSource) {
        final status = await ref
            .read(systemHealthProvider)
            .getConnectionStatus();
        if (!status.connected) {
          state = status.state;
        } else {
          final sources = await ref.read(healthDataRepoProvider).sources();
          state =
              sources.any(
                (source) => _matchesSource(descriptor.id, source.provider),
              )
              ? 'CONNECTED'
              : 'AVAILABLE';
        }
      } else if (descriptor.category == HealthProviderCategory.systemHub) {
        final status = await ref
            .read(systemHealthProvider)
            .getConnectionStatus();
        state = status.state;
      } else if (descriptor.id == 'GOOGLE_HEALTH') {
        final status = await ref
            .read(wearableProviderServiceProvider)
            .googleHealthStatus();
        state = status.status;
        lastSync = status.lastSyncAt;
      } else if (descriptor.category == HealthProviderCategory.cloudProvider) {
        final status = await ref
            .read(wearableProviderServiceProvider)
            .directHealthStatus(descriptor.id);
        state = status.available ? status.status : 'UNAVAILABLE';
        lastSync = status.lastSyncAt;
      } else {
        final status = await ref
            .read(bleHeartRateServiceProvider)
            .currentStatus();
        state = status.connected
            ? 'CONNECTED'
            : status.supported
            ? 'AVAILABLE'
            : 'UNAVAILABLE';
        _connectedBleIdentifier = status.connected ? status.identifier : null;
        if (status.connected) _selectedBleIdentifier = status.identifier;
      }
      if (mounted) {
        setState(() {
          _state = state;
          _lastSyncAt = lastSync;
          if (!preserveMessage) _message = null;
        });
      }
    } on WearableProviderException catch (error) {
      if (mounted) {
        setState(() {
          _state = 'ERROR';
          _message = error.message;
        });
      }
    }
  }

  Future<void> _primaryAction(HealthProviderDescriptor descriptor) async {
    await _run(() async {
      if (descriptor.category == HealthProviderCategory.systemHub ||
          descriptor.category == HealthProviderCategory.indirectSource) {
        final provider = ref.read(systemHealthProvider);
        final status = await provider.connect();
        if (status.state == 'CONNECTED') {
          final result = await provider.syncRecentData();
          _message = result.recordsImported == 0
              ? 'Accesso attivo. Nessun nuovo dato disponibile oggi.'
              : '${result.recordsImported} riepiloghi aggiornati sul dispositivo.';
        } else {
          _message = 'Completa i permessi nel pannello salute del sistema.';
        }
      } else if (descriptor.id == 'GOOGLE_HEALTH') {
        final service = ref.read(wearableProviderServiceProvider);
        if (_state == 'CONNECTED') {
          await service.syncGoogleHealthToday();
          _message = 'Riepilogo Google Health aggiornato.';
        } else {
          await service.authorizeGoogleHealth();
          _message = 'Completa il consenso nel browser, poi torna qui.';
        }
      } else {
        final service = ref.read(wearableProviderServiceProvider);
        if (_state == 'CONNECTED') {
          final result = await service.syncDirectHealth(descriptor.id);
          _message = '${result.imported} metriche aggregate aggiornate.';
        } else {
          await service.authorizeDirectHealth(descriptor.id);
          _message = 'Completa il consenso nel browser, poi torna qui.';
        }
      }
    });
    await _refresh(preserveMessage: true);
  }

  Future<void> _disconnect(HealthProviderDescriptor descriptor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Scollegare ${descriptor.displayName}?'),
        content: const Text(
          'Momentum revocherà il collegamento e cancellerà gli aggregati '
          'importati da questo provider. I dati originali restano nel '
          'servizio del produttore.',
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
    await _run(() async {
      await ref.read(wearableProviderServiceProvider).disconnect(descriptor.id);
      _message = 'Provider scollegato e dati importati rimossi.';
    });
    await _refresh(preserveMessage: true);
  }

  Future<void> _deleteLocalHealthData(
    HealthProviderDescriptor descriptor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rimuovere i dati importati?'),
        content: const Text(
          'Momentum eliminerà dal telefono i riepiloghi e l’attribuzione '
          'della fonte. I dati originali restano nell’hub salute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final repository = ref.read(healthDataRepoProvider);
      final providers = descriptor.id == 'HELIO_STRAP_HEALTH_HUB'
          ? const {'HELIO_STRAP_HEALTH_HUB', 'ZEPP_HEALTH_HUB'}
          : {descriptor.id};
      for (final provider in providers) {
        await repository.deleteProviderData(provider);
      }
      _state = 'AVAILABLE';
      _message = 'Dati importati rimossi dal dispositivo.';
    });
    await _refresh(preserveMessage: true);
  }

  Future<void> _disconnectBle() async {
    await _run(() async {
      await ref.read(bleHeartRateDataProvider).disconnect();
      _latestMeasurement = null;
      _connectedBleIdentifier = null;
      _state = 'AVAILABLE';
      _message = 'Sensore scollegato.';
    });
  }

  Future<void> _forgetBle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dimenticare il sensore?'),
        content: const Text(
          'Il collegamento e i dati locali del sensore verranno rimossi. '
          'Potrai associarlo nuovamente in seguito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dimentica'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await ref.read(bleHeartRateDataProvider).deleteImportedData();
      _bleDevices = const [];
      _latestMeasurement = null;
      _connectedBleIdentifier = null;
      _selectedBleIdentifier = null;
      _state = 'AVAILABLE';
      _message = 'Sensore e dati locali rimossi.';
    });
  }

  Future<void> _scanBle() async {
    if (_busy || _scanningBle || _connectingBleIdentifier != null) return;
    setState(() => _scanningBle = true);
    try {
      await _run(() async {
        final service = ref.read(bleHeartRateServiceProvider);
        final adapter = ref.read(bleHeartRateDataProvider);
        var status = await adapter.getConnectionStatus();
        if (status.authorizedMetrics.isEmpty) status = await adapter.connect();
        if (status.authorizedMetrics.isEmpty) {
          throw const BleHeartRateException('permissions_required');
        }
        final devices = await service.scan();
        _bleDevices = devices;
        final selectionStillAvailable = devices.any(
          (device) => device.identifier == _selectedBleIdentifier,
        );
        if (!selectionStillAvailable) {
          _selectedBleIdentifier = devices.length == 1
              ? devices.single.identifier
              : null;
        }
        if (_state != 'CONNECTED') _state = 'AVAILABLE';
        _message = devices.isEmpty
            ? 'Nessun sensore compatibile trovato. Attivalo e riprova.'
            : '${devices.length} sensori compatibili trovati.';
      });
    } finally {
      if (mounted) setState(() => _scanningBle = false);
    }
  }

  Future<void> _connectBle(BleHeartRateDevice device) async {
    if (_busy) return;
    setState(() {
      _selectedBleIdentifier = device.identifier;
      _connectingBleIdentifier = device.identifier;
    });
    await _run(() async {
      await ref.read(bleHeartRateServiceProvider).connect(device);
      _connectedBleIdentifier = device.identifier;
      _state = 'CONNECTED';
      _message = '${device.name} collegato. In attesa del primo battito.';
    });
    if (mounted) setState(() => _connectingBleIdentifier = null);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } on BleHeartRateException catch (error) {
      _state = 'ERROR';
      _message = error.userMessage;
    } on WearableProviderException catch (error) {
      _state = 'ERROR';
      _message = error.message;
    } catch (_) {
      _state = 'ERROR';
      _message =
          'Operazione non completata. I dati esistenti non sono stati modificati.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class BleHeartRateDeviceTile extends StatelessWidget {
  const BleHeartRateDeviceTile({
    required this.device,
    required this.onSelect,
    this.onConnect,
    this.isSelected = false,
    this.isConnecting = false,
    this.isConnected = false,
    super.key,
  });

  final BleHeartRateDevice device;
  final VoidCallback? onSelect;
  final VoidCallback? onConnect;
  final bool isSelected;
  final bool isConnecting;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final action = isSelected && onConnect != null ? onConnect : onSelect;
    final enabled = action != null && !isConnecting && !isConnected;
    final status = isConnected
        ? 'Sensore collegato'
        : isConnecting
        ? 'Collegamento in corso'
        : isSelected && onConnect != null
        ? 'Collega sensore'
        : isSelected
        ? 'Selezionato'
        : enabled
        ? 'Tocca per selezionare'
        : 'Sensore disponibile';

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${device.name}. ${_signalCopy(device.signal)}. $status',
      child: Material(
        color: isConnected
            ? RallyColors.win.withValues(alpha: 0.10)
            : isSelected
            ? RallyColors.lime.withValues(alpha: 0.10)
            : RallyColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isConnected
                ? RallyColors.win.withValues(alpha: 0.55)
                : isSelected
                ? RallyColors.lime.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? action : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 21,
                        backgroundColor: isConnected
                            ? RallyColors.win.withValues(alpha: 0.16)
                            : RallyColors.lime.withValues(alpha: 0.10),
                        child: Icon(
                          isConnected ? Icons.check : Icons.monitor_heart,
                          color: isConnected
                              ? RallyColors.win
                              : RallyColors.lime,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _signalCopy(device.signal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        child: isConnected
                            ? const Icon(
                                Icons.check_circle,
                                key: ValueKey('connected'),
                                color: RallyColors.win,
                                size: 24,
                              )
                            : Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? RallyColors.lime
                                    : Colors.white38,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? RallyColors.win.withValues(alpha: 0.14)
                        : isSelected
                        ? RallyColors.lime.withValues(alpha: 0.16)
                        : RallyColors.lime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isConnected
                          ? RallyColors.win.withValues(alpha: 0.45)
                          : isSelected
                          ? RallyColors.lime.withValues(alpha: 0.58)
                          : RallyColors.lime.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isConnecting)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      else
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.link,
                          size: 19,
                          color: isConnected
                              ? RallyColors.win
                              : RallyColors.lime,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isConnected
                                ? RallyColors.win
                                : RallyColors.lime,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({required this.descriptor, required this.connected});

  final HealthProviderDescriptor descriptor;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final hasArtwork = descriptor.artworkAsset.isNotEmpty;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasArtwork) ...[
            Semantics(
              image: true,
              label: 'Immagine ${descriptor.displayName}',
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: Image.asset(
                  descriptor.artworkAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Icon(
                    _providerIcon(descriptor),
                    size: 52,
                    color: RallyColors.lime,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasArtwork) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: RallyColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _providerIcon(descriptor),
                    size: 30,
                    color: RallyColors.lime,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descriptor.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descriptor.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusPill(
                          label: connected
                              ? 'Collegato'
                              : _supportLabel(descriptor.support),
                          color: connected
                              ? RallyColors.win
                              : RallyColors.training,
                        ),
                        if (descriptor.requiresPremium)
                          const _StatusPill(
                            label: 'Pro',
                            color: RallyColors.lime,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                connected ? 'Configurazione completata' : 'Configurazione',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                connected ? '3/3' : '1/3',
                style: const TextStyle(
                  color: RallyColors.lime,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: connected
                ? 'Configurazione completata'
                : 'Primo passaggio di tre',
            child: LinearProgressIndicator(
              value: connected ? 1 : 1 / 3,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: Colors.white10,
              color: RallyColors.lime,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.descriptor});
  final HealthProviderDescriptor descriptor;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'COSA RENDE DISPONIBILE',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: descriptor.capabilities.metrics
          .map(
            (metric) => Chip(
              avatar: Icon(_metricIcon(metric), size: 16),
              label: Text(_metricLabel(metric)),
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _PremiumHealthCard extends StatelessWidget {
  const _PremiumHealthCard({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'SINCRONIZZAZIONE CLOUD PREMIUM',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Il collegamento diretto al cloud del produttore e il backup '
          'multi-device usano il piano Pro. Apple Salute e Health '
          'Connect restano disponibili localmente senza costi cloud.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onUpgrade,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Scopri Pro'),
          ),
        ),
      ],
    ),
  );
}

class _DetectedSourcesCard extends ConsumerWidget {
  const _DetectedSourcesCard({required this.sources});
  final List<HealthDataSource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'ORIGINI RILEVATE',
    child: Column(
      children: [
        for (final source in sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.verified_outlined,
              color: RallyColors.win,
            ),
            title: Text(
              source.sourceApplication.isEmpty
                  ? source.provider
                  : source.sourceApplication,
            ),
            subtitle: Text(_sourceMetrics(source.availableMetricsJson)),
            trailing: PopupMenuButton<HealthMetricType>(
              tooltip: 'Scegli come origine preferita',
              onSelected: (metric) async {
                await ref
                    .read(healthDataRepoProvider)
                    .setPreferredSource(metric: metric, sourceId: source.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${source.sourceApplication} preferita per ${_metricLabel(metric)}.',
                    ),
                  ),
                );
              },
              itemBuilder: (_) =>
                  _sourceMetricTypes(source.availableMetricsJson)
                      .map(
                        (metric) => PopupMenuItem(
                          value: metric,
                          child: Text('Preferisci per ${_metricLabel(metric)}'),
                        ),
                      )
                      .toList(growable: false),
            ),
          ),
      ],
    ),
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0x1FC8F135),
          child: Text(
            '$index',
            style: const TextStyle(
              color: RallyColors.lime,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isError ? RallyColors.loss : RallyColors.win).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isError ? RallyColors.loss : RallyColors.win).withValues(
            alpha: 0.45,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? RallyColors.loss : RallyColors.win,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

bool _matchesSource(String descriptorId, String sourceProvider) =>
    descriptorId == sourceProvider ||
    (descriptorId == 'HELIO_STRAP_HEALTH_HUB' &&
        sourceProvider == 'ZEPP_HEALTH_HUB');

String _privacyCopy(
  HealthProviderDescriptor descriptor,
) => switch (descriptor.category) {
  HealthProviderCategory.systemHub || HealthProviderCategory.indirectSource =>
    'Lettura e deduplica avvengono sul telefono. Momentum conserva '
        'localmente solo riepiloghi e attribuzione della fonte. Nessun dato '
        'salute viene inviato al cloud senza una funzione Pro esplicita.',
  HealthProviderCategory.liveSensor =>
    'Il battito live resta sul dispositivo e viene associato alla partita '
        'solo su tua richiesta. L’identificativo Bluetooth non viene caricato '
        'su Supabase e la scansione termina automaticamente.',
  _ =>
    'OAuth e refresh token restano cifrati nelle Edge Functions. Nel cloud '
        'Momentum salva solo aggregati autorizzati; scollegando il provider '
        'revoca il token e cancella i dati importati.',
};

IconData _providerIcon(HealthProviderDescriptor descriptor) =>
    switch (descriptor.category) {
      HealthProviderCategory.systemHub => Icons.health_and_safety_outlined,
      HealthProviderCategory.cloudProvider => Icons.cloud_sync_outlined,
      HealthProviderCategory.liveSensor => Icons.monitor_heart_outlined,
      HealthProviderCategory.scoringWearable => Icons.watch_outlined,
      HealthProviderCategory.indirectSource => Icons.radar,
    };

String _supportLabel(HealthProviderSupportStatus status) => switch (status) {
  HealthProviderSupportStatus.production => 'Produzione',
  HealthProviderSupportStatus.beta => 'Beta',
  HealthProviderSupportStatus.indirect => 'Via hub salute',
  HealthProviderSupportStatus.experimental => 'Sperimentale',
  HealthProviderSupportStatus.internal => 'Test interno',
  HealthProviderSupportStatus.research => 'In valutazione',
  HealthProviderSupportStatus.notSupported => 'Non supportato',
};

String _metricLabel(HealthMetricType metric) => switch (metric) {
  HealthMetricType.workout => 'Allenamenti',
  HealthMetricType.heartRate => 'Battito',
  HealthMetricType.activeEnergy => 'Calorie attive',
  HealthMetricType.totalEnergy => 'Calorie totali',
  HealthMetricType.steps => 'Passi',
  HealthMetricType.exerciseMinutes => 'Minuti attivi',
  HealthMetricType.distance => 'Distanza',
  HealthMetricType.hrv => 'HRV',
  HealthMetricType.sleep => 'Sonno',
  HealthMetricType.sleepScore => 'Qualità sonno',
  HealthMetricType.readiness => 'Readiness',
  HealthMetricType.recovery => 'Recovery',
  HealthMetricType.strain => 'Strain',
  HealthMetricType.restingHeartRate => 'Battito a riposo',
};

IconData _metricIcon(HealthMetricType metric) => switch (metric) {
  HealthMetricType.heartRate ||
  HealthMetricType.restingHeartRate => Icons.favorite_outline,
  HealthMetricType.sleep ||
  HealthMetricType.sleepScore => Icons.bedtime_outlined,
  HealthMetricType.hrv ||
  HealthMetricType.recovery ||
  HealthMetricType.readiness => Icons.monitor_heart_outlined,
  HealthMetricType.workout ||
  HealthMetricType.exerciseMinutes ||
  HealthMetricType.strain => Icons.fitness_center,
  HealthMetricType.steps || HealthMetricType.distance => Icons.directions_walk,
  _ => Icons.local_fire_department_outlined,
};

String _sourceMetrics(String raw) {
  try {
    final values = (jsonDecode(raw) as List).map((value) => value.toString());
    return values.isEmpty ? 'Fonte rilevata' : values.join(' · ');
  } catch (_) {
    return 'Fonte rilevata';
  }
}

List<HealthMetricType> _sourceMetricTypes(String raw) {
  try {
    return (jsonDecode(raw) as List)
        .map((value) => HealthMetricType.tryFromWire(value.toString()))
        .nonNulls
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String _signalCopy(int signal) => switch (signal) {
  >= -60 => 'Segnale ottimo',
  >= -75 => 'Segnale buono',
  >= -90 => 'Segnale debole',
  _ => 'Avvicina il sensore',
};

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} · '
      '${two(local.hour)}:${two(local.minute)}';
}
