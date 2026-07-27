library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../domain/entitlements.dart';
import '../../services/watch_compatibility.dart';
import '../../services/wearable_cloud_sync.dart';
import '../../services/watch_sync.dart';
import '../../services/wearable_provider_service.dart';

class WatchSetupScreen extends ConsumerStatefulWidget {
  const WatchSetupScreen({super.key});

  @override
  ConsumerState<WatchSetupScreen> createState() => _WatchSetupScreenState();
}

class _WatchSetupScreenState extends ConsumerState<WatchSetupScreen> {
  static const _lastStep = 6;

  /// SEE (incl. Italy): Fitbit Gallery no longer hosts third-party apps (2024).
  static const _seeCountryCodes = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
    'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
    'SI', 'ES', 'SE',
  };

  bool get _isFitbitOsUnavailableInRegion {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase();
    return code != null && _seeCountryCodes.contains(code);
  }

  int _step = 0;
  WatchFamily? _family;
  bool _busy = false;
  bool _connectionTested = false;
  bool _pointTested = false;
  bool _oauthStarted = false;
  bool _feedbackSuccess = false;
  String? _feedback;
  Map<String, Object?> _garminStatus = const {};
  List<GarminDeviceInfo> _garminDevices = const [];
  GarminDeviceInfo? _garminDevice;
  FitbitPairingCode? _fitbitCode;
  String _fitbitStatus = 'DISCONNECTED';
  int _fitbitActiveDevices = 0;
  DateTime? _fitbitProbeAfter;
  GoogleHealthStatus? _googleHealth;
  GoogleHealthToday? _googleToday;

  WearableProviderService get _providers =>
      ref.read(wearableProviderServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(watchSyncProvider.notifier).refresh();
      final catalog = await ref.read(watchCompatibilityProvider.future);
      final saved = await ref.read(connectedDeviceRepoProvider).all();
      if (!mounted) return;
      final device = saved.firstOrNull;
      WatchFamily? restored;
      if (device != null && device.family.isNotEmpty) {
        restored = catalog
            .forCurrentPhone()
            .where(
              (family) =>
                  family.family == device.family ||
                  family.watchOs == device.platform ||
                  family.provider == device.platform,
            )
            .firstOrNull;
      }
      setState(() {
        _family = restored;
        if (device != null && restored != null) {
          _step = device.setupStep >= _lastStep
              ? 2
              : device.setupStep.clamp(0, _lastStep);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(watchCompatibilityProvider);
    final watch = ref.watch(watchSyncProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configura wearable'),
        leading: IconButton(
          onPressed: _busy
              ? null
              : _step == 0
              ? () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/devices');
                  }
                }
              : _back,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Indietro',
        ),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Guida compatibilità non disponibile: $error'),
          ),
        ),
        data: (data) {
          return Column(
            children: [
              _Progress(step: _step, total: _lastStep + 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: SingleChildScrollView(
                    key: ValueKey('${_family?.id}:$_step'),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      children: [
                        _content(data, watch),
                        if (_feedback != null) ...[
                          const SizedBox(height: 16),
                          _InfoBox(
                            icon: _feedbackSuccess
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            text: _feedback!,
                            success: _feedbackSuccess,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _advance(data, watch),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _step == _lastStep
                                ? Icons.check
                                : Icons.arrow_forward,
                          ),
                    label: Text(_actionLabel(watch)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(WatchCompatibilityCatalog catalog, WatchSyncState watch) {
    if (_step == 0) return _StepIntro(platform: catalog.phonePlatform);
    if (_step == 1) {
      return _FamilyStep(
        families: catalog.forCurrentPhone(),
        selected: _family,
        onSelected: (family) => setState(() {
          _family = family;
          _feedback = null;
          _connectionTested = false;
          _pointTested = false;
        }),
      );
    }
    final family = _family;
    if (family == null) return const SizedBox.shrink();
    final content = family.isRetired
        ? _RetiredTizenStep(done: _step == _lastStep)
        : switch (family.connectionMode) {
            'garmin_mobile_sdk' => _garminContent(family),
            'fitbit_companion' => _fitbitContent(family),
            'google_health_oauth' => _googleHealthContent(family),
            _ => _nativeContent(family, watch),
          };
    return Column(
      children: [
        _WearableFamilyArtwork(family: family),
        const SizedBox(height: 14),
        content,
      ],
    );
  }

  Widget _nativeContent(
    WatchFamily family,
    WatchSyncState watch,
  ) => switch (_step) {
    2 => _DiagnosticStep(state: watch),
    3 => _CompanionStep(family: family, state: watch),
    4 => _TestStep(
      icon: Icons.wifi_tethering,
      title: 'Testa la comunicazione',
      message:
          'Invieremo un segnale reale. Il watch deve vibrare e confermare la ricezione.',
      completed: _connectionTested,
    ),
    5 => _TestStep(
      icon: Icons.add_circle_outline,
      title: 'Prova il gesto punto',
      message:
          'Il test riproduce il feedback aptico senza creare o modificare partite.',
      completed: _pointTested,
    ),
    _ => _DoneStep(
      family: family,
      connected: _connectionTested && _pointTested,
      healthOnly: false,
    ),
  };

  Widget _garminContent(WatchFamily family) => switch (_step) {
    2 => _StepShell(
      icon: Icons.watch_outlined,
      title: 'Garmin Connect IQ',
      message:
          'Momentum usa il Mobile SDK ufficiale Garmin. Garmin Connect serve per condividere il watch con Momentum.',
      child: Column(
        children: [
          _CheckRow(
            label: 'Garmin Connect installato',
            ok: _garminStatus['companionInstalled'] == true,
          ),
          _CheckRow(
            label: 'SDK Connect IQ pronto',
            ok: _garminStatus['sdkReady'] == true,
          ),
          _CheckRow(
            label: 'Garmin condiviso con Momentum',
            ok: _garminDevices.isNotEmpty,
          ),
        ],
      ),
    ),
    3 => _StepShell(
      icon: _garminDevice?.appRegistered == true
          ? Icons.download_done
          : Icons.phonelink_setup,
      title: _garminDevices.isEmpty
          ? 'Seleziona il Garmin'
          : 'Verifica Momentum sul watch',
      message: _garminDevices.isEmpty
          ? 'Su iPhone si aprirà Garmin Connect per scegliere quali dispositivi condividere. Su Android usiamo i Garmin già associati.'
          : 'Controlleremo installazione, connessione Bluetooth e mailbox Connect IQ.',
      child: RadioGroup<String>(
        groupValue: _garminDevice?.nativeId,
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _garminDevice = _garminDevices.firstWhere(
              (item) => item.nativeId == value,
            );
          });
        },
        child: Column(
          children: [
            for (final device in _garminDevices)
              RadioListTile<String>(
                value: device.nativeId,
                title: Text(device.name),
                subtitle: Text(
                  device.model.isEmpty
                      ? device.status
                      : '${device.model} · ${device.status}',
                ),
                activeColor: RallyColors.lime,
              ),
            if (_garminDevices.isEmpty)
              const _InfoBox(
                icon: Icons.privacy_tip_outlined,
                text:
                    'La selezione è esplicita. UUID e identificativi Garmin restano sul telefono; al database arriva solo l’account Momentum.',
              ),
          ],
        ),
      ),
    ),
    4 => _TestStep(
      icon: Icons.wifi_tethering,
      title: 'Test mailbox Garmin',
      message:
          'Invieremo un PING tramite Garmin Connect IQ e aspetteremo il PONG del watch.',
      completed: _connectionTested,
    ),
    5 => _TestStep(
      icon: Icons.vibration,
      title: 'Prova feedback punto',
      message:
          'Il Garmin vibra e risponde senza modificare la partita o lo storico.',
      completed: _pointTested,
    ),
    _ => _DoneStep(
      family: family,
      connected: _connectionTested && _pointTested,
      healthOnly: false,
    ),
  };

  Widget _fitbitContent(WatchFamily family) => switch (_step) {
    2 => _StepShell(
      icon: Icons.pin_outlined,
      title: 'Prepara Fitbit OS',
      message:
          'Genereremo un codice monouso. Nessuna password Fitbit viene condivisa con Momentum.',
      child: const _InfoBox(
        icon: Icons.info_outline,
        text:
            'Fuori dallo Spazio Economico Europeo (SEE): apri la Gallery Fitbit, '
            'installa Momentum e tieni vicino telefono e watch. Il codice dura '
            '10 minuti.\n\n'
            'Italia e SEE: Google ha rimosso le app di terze parti dalla Gallery '
            'Fitbit (giugno 2024). Questa integrazione non è installabile lì; '
            'usa Apple Watch, Wear OS o Garmin se disponibili.',
      ),
    ),
    3 => _StepShell(
      icon: Icons.password,
      title: 'Inserisci il codice in Fitbit',
      message: _fitbitCode == null
          ? 'Tocca il pulsante per generare il codice.'
          : 'In Fitbit: Momentum → Impostazioni → Codice di associazione.',
      child: _fitbitCode == null
          ? const SizedBox.shrink()
          : Semantics(
              label: 'Codice Fitbit ${_fitbitCode!.displayCode}',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: RallyColors.lime.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RallyColors.lime),
                ),
                child: Text(
                  _fitbitCode!.displayCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: RallyColors.lime,
                  ),
                ),
              ),
            ),
    ),
    4 => _TestStep(
      icon: Icons.cloud_done_outlined,
      title: 'Verifica associazione',
      message:
          'Il companion Fitbit deve aver scambiato il codice con un token revocabile e protetto sul server.',
      completed: _fitbitStatus == 'CONNECTED',
    ),
    5 => _TestStep(
      icon: Icons.add_circle_outline,
      title: 'Punto di prova dal Fitbit',
      message:
          'Apri Momentum sul Fitbit e segna un punto nuovo. Controlliamo solo '
          'la coda cloud: gli eventi restano in attesa e verranno applicati '
          'alla prossima sincronizzazione (nessuna cancellazione).',
      completed: _pointTested,
    ),
    _ => _DoneStep(
      family: family,
      connected:
          _fitbitStatus == 'CONNECTED' &&
          _fitbitActiveDevices > 0 &&
          _pointTested,
      healthOnly: false,
    ),
  };

  Widget _googleHealthContent(WatchFamily family) => switch (_step) {
    2 => _StepShell(
      icon: Icons.health_and_safety_outlined,
      title: family.screenless ? 'Fitbit Air: dati salute' : 'Google Health',
      message: family.screenless
          ? 'Fitbit Air non ha uno schermo: può alimentare il riepilogo salute, ma non può mostrare pulsanti di scoring.'
          : 'Collega in sola lettura i dati fitness disponibili nel tuo account Google.',
      child: Column(
        children: [
          _CheckRow(label: 'Scoring sul dispositivo', ok: !family.screenless),
          const _CheckRow(label: 'Consenso Google separato', ok: true),
          const _CheckRow(label: 'Accesso salute in sola lettura', ok: true),
        ],
      ),
    ),
    3 => _StepShell(
      icon: Icons.verified_user_outlined,
      title: _googleHealth?.connected == true
          ? 'Google Health collegato'
          : 'Concedi il consenso',
      message:
          'Momentum richiede solo attività e metriche utili. Puoi revocare il collegamento in qualsiasi momento.',
      child: _InfoBox(
        icon: Icons.lock_outline,
        text: _oauthStarted && _googleHealth?.connected != true
            ? 'Completa il consenso nel browser, torna qui e tocca “Verifica collegamento”.'
            : 'Token e refresh token sono cifrati server-side; non vengono mai salvati nel client Flutter.',
      ),
    ),
    4 => _TestStep(
      icon: Icons.sync,
      title: 'Sincronizza la giornata corrente',
      message:
          'La query usa il giorno civile locale da mezzanotte a ora, non una finestra mobile di 24 ore.',
      completed: _googleToday != null,
    ),
    5 => _StepShell(
      icon: Icons.insights_outlined,
      title: 'Riepilogo di oggi',
      message: _googleToday == null
          ? 'Sincronizza prima i dati disponibili.'
          : '${_googleToday!.steps} passi · ${_googleToday!.exerciseMinutes} min attivi · ${_googleToday!.activeEnergyKcal.toStringAsFixed(0)} kcal',
      child: const _InfoBox(
        icon: Icons.schedule,
        text:
            'Momentum aggiorna il riepilogo quando apri la sezione e non usa questi dati per pubblicità o profilazione.',
        success: true,
      ),
    ),
    _ => _DoneStep(
      family: family,
      connected: _googleHealth?.connected == true,
      healthOnly: true,
    ),
  };

  String _actionLabel(WatchSyncState watch) {
    if (_step == _lastStep) return 'Fine';
    final family = _family;
    if (family == null || _step < 2) return 'Continua';
    if (family.isRetired) return 'Ho capito';
    return switch (family.connectionMode) {
      'garmin_mobile_sdk' => switch (_step) {
        2 =>
          _garminStatus['companionInstalled'] == true
              ? 'Cerca dispositivi'
              : 'Installa Garmin Connect',
        3 =>
          _garminDevices.isEmpty
              ? 'Seleziona in Garmin Connect'
              : 'Verifica app',
        4 => _connectionTested ? 'Continua' : 'Invia PING',
        5 => _pointTested ? 'Continua' : 'Prova vibrazione',
        _ => 'Continua',
      },
      'fitbit_companion' => switch (_step) {
        2 => 'Genera codice',
        3 || 4 => 'Verifica collegamento',
        5 => _pointTested ? 'Continua' : 'Controlla il punto',
        _ => 'Continua',
      },
      'google_health_oauth' => switch (_step) {
        3 => _oauthStarted ? 'Verifica collegamento' : 'Collega Google Health',
        4 => 'Sincronizza oggi',
        _ => 'Continua',
      },
      _ => switch (_step) {
        2 || 3 => watch.companionInstalled ? 'Continua' : 'Ricontrolla',
        4 => _connectionTested ? 'Continua' : 'Invia segnale',
        5 => _pointTested ? 'Continua' : 'Prova feedback punto',
        _ => 'Continua',
      },
    };
  }

  Future<void> _advance(
    WatchCompatibilityCatalog catalog,
    WatchSyncState watch,
  ) async {
    setState(() => _feedback = null);
    if (_step == 0) {
      _go(1);
      return;
    }
    if (_step == 1) {
      final family = _family;
      if (family == null) {
        setState(() => _feedback = 'Scegli la famiglia del tuo wearable.');
        return;
      }
      if (!family.isSupported && !family.isRetired) {
        setState(() => _feedback = 'Questa piattaforma non è supportata.');
        return;
      }
      // Fitbit OS third-party Gallery apps removed in SEE (incl. Italy) June 2024.
      if (family.provider == 'FITBIT_OS' && _isFitbitOsUnavailableInRegion) {
        setState(
          () => _feedback =
              'Fitbit OS non è installabile in Italia/SEE (Gallery terze parti '
              'rimossa). Usa Apple Watch, Wear OS o Garmin.',
        );
        return;
      }
      if (!_planAllows(family, ref.read(entitlementsProvider))) {
        setState(
          () => _feedback = family.requiresPlan == 'pro'
              ? 'Google Health e Fitbit Air richiedono Momentum Pro.'
              : 'Garmin e Fitbit OS con sync cloud richiedono Momentum Plus.',
        );
        if (mounted) {
          await pushPaywall(
            context,
            plan: family.requiresPlan == 'pro' ? Plan.pro : Plan.plus,
            reason: family.requiresPlan == 'pro'
                ? 'Google Health e Fitbit Air richiedono il piano Pro.'
                : 'Garmin e Fitbit OS richiedono il piano Plus.',
            returnTo: '/devices/setup',
          );
        }
        return;
      }
      await _saveProgress(watch, 2);
      _go(2);
      return;
    }
    final family = _family!;
    if (family.isRetired) {
      if (_step == 2) {
        await _saveProgress(watch, _lastStep);
        _go(_lastStep);
      } else if (mounted) {
        AppNavigation.popOrGo(context, fallback: AppLocations.devices);
      }
      return;
    }
    if (_step == _lastStep) {
      if (mounted) {
        AppNavigation.popOrGo(context, fallback: AppLocations.devices);
      }
      return;
    }
    switch (family.connectionMode) {
      case 'garmin_mobile_sdk':
        await _advanceGarmin(watch);
      case 'fitbit_companion':
        await _advanceFitbit(watch);
      case 'google_health_oauth':
        await _advanceGoogleHealth(watch);
      default:
        await _advanceNative(catalog, watch);
    }
  }

  Future<void> _advanceNative(
    WatchCompatibilityCatalog catalog,
    WatchSyncState watch,
  ) async {
    switch (_step) {
      case 2:
        await _refreshNative();
        final next = ref.read(watchSyncProvider);
        if (!next.paired) {
          _message(
            'Avvicina telefono e watch, attiva Bluetooth e completa il pairing di sistema.',
          );
          return;
        }
        _go(3);
      case 3:
        await _refreshNative();
        if (!ref.read(watchSyncProvider).companionInstalled) {
          _message(_nativeCompanionHelp(catalog.phonePlatform));
          return;
        }
        _go(4);
      case 4:
        if (!_connectionTested && !await _testNative(point: false)) return;
        _go(5);
      case 5:
        if (!_pointTested && !await _testNative(point: true)) return;
        await _saveProgress(ref.read(watchSyncProvider), _lastStep);
        _go(_lastStep);
    }
  }

  Future<void> _advanceGarmin(WatchSyncState watch) async {
    switch (_step) {
      case 2:
        if (!await _refreshGarmin()) return;
        if (_garminStatus['companionInstalled'] != true) {
          await _providers.openGarminCompanionStore();
          _message('Installa Garmin Connect, associa il watch e torna qui.');
          return;
        }
        if (_garminDevices.isEmpty) {
          await _providers.selectGarminDevices();
          _message(
            'Seleziona il Garmin in Garmin Connect, poi torna qui e ripeti la verifica.',
          );
          return;
        }
        _go(3);
      case 3:
        final device = _garminDevice ?? _garminDevices.firstOrNull;
        if (device == null) {
          await _providers.selectGarminDevices();
          _message('Seleziona prima un Garmin.');
          return;
        }
        final registration = await _perform(
          () => _providers.registerGarminDevice(device.nativeId),
        );
        if (registration == null) return;
        if (registration['appInstalled'] != true) {
          await _providers.openGarminStore(device.nativeId);
          _message(
            'Installa Momentum dal Connect IQ Store sul Garmin, poi torna e ricontrolla.',
          );
          return;
        }
        setState(() {
          _garminDevice = GarminDeviceInfo(
            nativeId: device.nativeId,
            deviceId: device.deviceId,
            name: device.name,
            model: device.model,
            status: device.status,
            appRegistered: true,
          );
        });
        await _saveProgress(watch, 4);
        _go(4);
      case 4:
        final device = _garminDevice;
        if (device == null) return;
        final ok = await _perform(() => _providers.testGarmin(device.nativeId));
        if (ok != true) {
          _message(
            'Nessun PONG. Apri Momentum sul Garmin e avvicina il telefono.',
          );
          return;
        }
        setState(() => _connectionTested = true);
        _go(5);
      case 5:
        final device = _garminDevice;
        if (device == null) return;
        final ok = await _perform(
          () => _providers.testGarmin(device.nativeId, point: true),
        );
        if (ok != true) {
          _message('Il test aptico non è stato confermato dal Garmin.');
          return;
        }
        setState(() => _pointTested = true);
        unawaited(
          _providers.syncGarminQueue(
            commitEventsToPhone: (events) async {
              await ref
                  .read(wearableCloudSyncProvider)
                  .commitGarminEvents(events);
            },
          ),
        );
        await _saveProgress(watch, _lastStep);
        _go(_lastStep);
    }
  }

  Future<void> _advanceFitbit(WatchSyncState watch) async {
    switch (_step) {
      case 2:
        final code = await _perform(_providers.createFitbitPairing);
        if (code == null) return;
        setState(() => _fitbitCode = code);
        _go(3);
      case 3:
        final info = await _perform(_providers.fitbitConnectionInfo);
        if (info == null) return;
        setState(() {
          _fitbitStatus = info.status;
          _fitbitActiveDevices = info.activeDevices;
        });
        if (!info.isPairedLive) {
          _message(
            'Il codice non è ancora stato confermato dal companion Fitbit, '
            'oppure non c’è un token dispositivo attivo.',
          );
          return;
        }
        _go(4);
      case 4:
        final info = await _perform(_providers.fitbitConnectionInfo);
        if (info == null || !info.isPairedLive) {
          _message(
            'Fitbit non ha un token attivo sul server Momentum. '
            'Inserisci di nuovo il codice sul watch.',
          );
          return;
        }
        setState(() {
          _fitbitStatus = info.status;
          _fitbitActiveDevices = info.activeDevices;
          _connectionTested = true;
          _fitbitProbeAfter = DateTime.now().toUtc();
        });
        _go(5);
      case 5:
        // Non-destructive: drain only, never merge/ACK production inbox.
        final found = await _perform(
          () => _providers.probeFitbitInbox(
            notBefore: _fitbitProbeAfter,
            requirePoint: true,
          ),
        );
        if (found != true) {
          _message(
            'Nessun punto nuovo in coda. Apri Momentum sul Fitbit, segna un '
            'punto e riprova (gli eventi restano in coda).',
          );
          return;
        }
        setState(() {
          _pointTested = true;
          _feedbackSuccess = true;
          _feedback = 'Punto di prova ricevuto. La coda non è stata svuotata.';
        });
        await _saveProgress(watch, _lastStep);
        _go(_lastStep);
    }
  }

  Future<void> _advanceGoogleHealth(WatchSyncState watch) async {
    switch (_step) {
      case 2:
        final status = await _perform(_providers.googleHealthStatus);
        if (status != null) setState(() => _googleHealth = status);
        _go(3);
      case 3:
        if (!_oauthStarted && _googleHealth?.connected != true) {
          final started = await _perform(() async {
            await _providers.authorizeGoogleHealth();
            return true;
          });
          if (started == true) {
            setState(() => _oauthStarted = true);
            _message('Completa il consenso Google e torna in Momentum.');
          }
          return;
        }
        final status = await _perform(_providers.googleHealthStatus);
        if (status == null || !status.connected) {
          _message(
            'Collegamento non ancora completato. Controlla il consenso Google.',
          );
          return;
        }
        setState(() {
          _googleHealth = status;
          _connectionTested = true;
        });
        _go(4);
      case 4:
        final today = await _perform(_providers.syncGoogleHealthToday);
        if (today == null) return;
        setState(() => _googleToday = today);
        _go(5);
      case 5:
        await _saveProgress(watch, _lastStep);
        _go(_lastStep);
    }
  }

  Future<void> _refreshNative() async {
    setState(() => _busy = true);
    await ref.read(watchSyncProvider.notifier).refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _refreshGarmin() async {
    final status = await _perform(_providers.garminStatus);
    if (status == null) return false;
    final devices = await _perform(_providers.garminDevices);
    if (devices == null) return false;
    if (!mounted) return false;
    setState(() {
      _garminStatus = status;
      _garminDevices = devices;
      _garminDevice = devices
          .where((item) => item.nativeId == _garminDevice?.nativeId)
          .firstOrNull;
      _garminDevice ??= devices.firstOrNull;
    });
    return true;
  }

  Future<bool> _testNative({required bool point}) async {
    setState(() => _busy = true);
    final ok = await ref
        .read(watchSyncProvider.notifier)
        .testConnection(point: point);
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (point) {
        _pointTested = ok;
      } else {
        _connectionTested = ok;
      }
      _feedback = ok
          ? 'Conferma ricevuta dal watch.'
          : 'Nessuna conferma. Apri Momentum sul watch e riprova.';
    });
    return ok;
  }

  Future<T?> _perform<T>(Future<T> Function() action) async {
    if (mounted) setState(() => _busy = true);
    try {
      final result = await action();
      if (mounted) setState(() => _feedbackSuccess = true);
      return result;
    } on WearableProviderException catch (error) {
      _message(error.message, success: false);
      return null;
    } on PlatformException catch (error) {
      _message(
        error.message ?? 'Provider non disponibile su questo dispositivo.',
        success: false,
      );
      return null;
    } catch (_) {
      _message(
        'Operazione non riuscita. Riprova senza perdere il progresso.',
        success: false,
      );
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _planAllows(WatchFamily family, Entitlements entitlements) =>
      switch (family.requiresPlan) {
        'pro' => entitlements.premiumOverride || entitlements.healthConnectSync,
        'plus' => entitlements.premiumOverride || entitlements.duoMode,
        _ => true,
      };

  Future<void> _saveProgress(WatchSyncState watch, int step) async {
    final family = _family;
    if (family == null) return;
    final providerDeviceId = _garminDevice?.deviceId;
    final id = providerDeviceId?.isNotEmpty == true
        ? 'watch_garmin_$providerDeviceId'
        : 'watch_${family.id}';
    final isNative =
        family.connectionMode == 'watch_connectivity' ||
        family.connectionMode == 'wear_data_layer';
    final isRetired =
        family.isRetired || family.connectionMode == 'migration_guidance';
    // Scoring readiness requires proof. Health-only never becomes READY.
    // Never inherit radio-only watch.ready — require guided ping + point proof.
    final fullyProven = switch (family.connectionMode) {
      'garmin_mobile_sdk' => _connectionTested && _pointTested,
      'fitbit_companion' =>
        _fitbitStatus == 'CONNECTED' &&
            _fitbitActiveDevices > 0 &&
            _pointTested,
      'google_health_oauth' => _googleHealth?.connected == true,
      'migration_guidance' => false,
      // Native Apple Watch / Wear OS: same proof bar as Garmin.
      _ => isRetired ? false : (_connectionTested && _pointTested),
    };
    final status = switch (family.connectionMode) {
      'google_health_oauth' => fullyProven ? 'CONNECTED' : 'NOT_REACHABLE',
      'migration_guidance' => 'UNSUPPORTED',
      _ when isRetired => 'UNSUPPORTED',
      'fitbit_companion' when fullyProven => 'READY',
      'fitbit_companion'
          when _fitbitStatus == 'CONNECTED' && _fitbitActiveDevices > 0 =>
        'CONNECTED',
      _ => fullyProven
          ? 'READY'
          : 'NOT_REACHABLE',
    };
    await ref
        .read(connectedDeviceRepoProvider)
        .upsertDiagnostics(
          id: isNative ? null : id,
          platform: isNative ? watch.platformLabel : family.provider,
          family: family.family,
          displayName: _garminDevice?.name ?? family.family,
          status: status,
          capabilitiesJson: jsonEncode({
            'provider': family.provider,
            'features': family.features,
            'connectionMode': family.connectionMode,
            'screenless': family.screenless,
          }),
          companionInstalled: switch (family.connectionMode) {
            'garmin_mobile_sdk' => _garminStatus['companionInstalled'] == true,
            'fitbit_companion' =>
              _fitbitStatus == 'CONNECTED' && _fitbitActiveDevices > 0,
            'google_health_oauth' => _googleHealth?.connected == true,
            'migration_guidance' => false,
            _ => isRetired ? false : watch.companionInstalled,
          },
          permissionsComplete: family.connectionMode == 'google_health_oauth'
              ? _googleHealth?.connected == true
              : fullyProven,
          setupStep: step,
          connected: fullyProven && !isRetired,
        );
  }

  void _go(int step) {
    if (!mounted) return;
    setState(() {
      _step = step.clamp(0, _lastStep);
      _feedback = null;
    });
  }

  void _back() => _go(_step - 1);

  void _message(String value, {bool success = false}) {
    if (mounted) {
      setState(() {
        _feedback = value;
        _feedbackSuccess = success;
      });
    }
  }

  String _nativeCompanionHelp(String phonePlatform) => phonePlatform == 'ios'
      ? 'Apri l’app Watch su iPhone, cerca Momentum in “App disponibili” e tocca Installa.'
      : 'Sul watch apri Google Play, cerca Momentum e installa la companion.';
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              'Passaggio ${step + 1} di $total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white60,
              ),
            ),
            const Spacer(),
            Text(
              '${((step + 1) / total * 100).round()}%',
              style: const TextStyle(fontSize: 12, color: RallyColors.lime),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (step + 1) / total,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    ),
  );
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.platform});
  final String platform;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: platform == 'ios' ? Icons.phone_iphone : Icons.android,
    showIcon: true,
    title: platform == 'ios' ? 'iPhone rilevato' : 'Android rilevato',
    message:
        'Momentum adatterà il percorso ad Apple Watch, Wear OS, Garmin, Fitbit o servizi salute compatibili.',
    child: const _InfoBox(
      icon: Icons.privacy_tip_outlined,
      text:
          'Il rilevamento resta locale. Non usiamo seriali, MAC o identificativi pubblicitari.',
    ),
  );
}

class _FamilyStep extends StatelessWidget {
  const _FamilyStep({
    required this.families,
    required this.selected,
    required this.onSelected,
  });
  final List<WatchFamily> families;
  final WatchFamily? selected;
  final ValueChanged<WatchFamily> onSelected;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: Icons.watch_outlined,
    showIcon: true,
    title: 'Quale wearable utilizzi?',
    message: 'Le opzioni riflettono capacità e limiti reali della piattaforma.',
    child: RadioGroup<String>(
      groupValue: selected?.id,
      onChanged: (id) {
        if (id == null) return;
        onSelected(families.firstWhere((family) => family.id == id));
      },
      child: Column(
        children: [
          for (final family in families)
            RadioListTile<String>(
              value: family.id,
              title: Text(family.family),
              subtitle: Text(switch (family.support) {
                'FULL' => 'Supporto completo · ${family.minimumVersion}',
                'CONDITIONAL' =>
                  'Modulo nativo · pubblicazione provider da completare',
                'HEALTH_ONLY' => 'Solo dati salute · nessuna UI sul wearable',
                'RETIRED' => 'Piattaforma ritirata dal produttore',
                _ => 'Non supportato',
              }, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              activeColor: RallyColors.lime,
              contentPadding: EdgeInsets.zero,
              secondary: _WearableFamilyArtwork(family: family, compact: true),
            ),
        ],
      ),
    ),
  );
}

class _WearableFamilyArtwork extends StatelessWidget {
  const _WearableFamilyArtwork({required this.family, this.compact = false});

  final WatchFamily family;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      family.screenless ? Icons.monitor_heart_outlined : Icons.watch_outlined,
      color: RallyColors.lime,
      size: compact ? 28 : 54,
    );
    if (family.artworkAsset.isEmpty) return fallback;

    final image = Image.asset(
      family.artworkAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: compact ? 180 : 720,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Center(child: fallback),
    );
    return Semantics(
      image: true,
      label: 'Anteprima ${family.family}',
      child: RepaintBoundary(
        child: compact
            ? ClipRect(child: SizedBox(width: 76, height: 57, child: image))
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 336),
                child: ClipRect(
                  child: AspectRatio(aspectRatio: 4 / 3, child: image),
                ),
              ),
      ),
    );
  }
}

class _DiagnosticStep extends StatelessWidget {
  const _DiagnosticStep({required this.state});
  final WatchSyncState state;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: Icons.manage_search,
    title: 'Controllo collegamento',
    message:
        'Verifichiamo pairing, companion e raggiungibilità senza inviare dati al cloud.',
    child: Column(
      children: [
        _CheckRow(label: 'Watch associato al telefono', ok: state.paired),
        _CheckRow(
          label: 'Companion Momentum installata',
          ok: state.companionInstalled,
        ),
        _CheckRow(label: 'Watch raggiungibile', ok: state.reachable),
      ],
    ),
  );
}

class _CompanionStep extends StatelessWidget {
  const _CompanionStep({required this.family, required this.state});
  final WatchFamily family;
  final WatchSyncState state;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: state.companionInstalled
        ? Icons.download_done
        : Icons.system_update_alt,
    title: state.companionInstalled
        ? 'Companion disponibile'
        : 'Installa la companion',
    message: state.companionInstalled
        ? 'Momentum è presente sul watch. Ora possiamo testare la comunicazione.'
        : family.watchOs == 'watchOS'
        ? 'Apri l’app Watch su iPhone e installa Momentum dalle app disponibili.'
        : 'Sul watch apri Google Play, cerca Momentum e completa l’installazione.',
    child: _InfoBox(
      icon: Icons.info_outline,
      text:
          family.limitations.firstOrNull ??
          'Mantieni telefono e watch vicini durante la verifica.',
    ),
  );
}

class _TestStep extends StatelessWidget {
  const _TestStep({
    required this.icon,
    required this.title,
    required this.message,
    required this.completed,
  });
  final IconData icon;
  final String title;
  final String message;
  final bool completed;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: completed ? Icons.check_circle : icon,
    title: title,
    message: message,
    child: completed
        ? const _InfoBox(
            icon: Icons.check,
            text: 'Test completato e confermato.',
            success: true,
          )
        : const SizedBox.shrink(),
  );
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.family,
    required this.connected,
    required this.healthOnly,
  });
  final WatchFamily family;
  final bool connected;
  final bool healthOnly;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: connected ? Icons.verified : Icons.info_outline,
    title: healthOnly ? 'Dati salute collegati' : 'Wearable pronto',
    message: connected
        ? '${family.family} ha completato le verifiche previste.'
        : 'La configurazione è salvata, ma il collegamento richiede ancora una verifica reale.',
    child: Column(
      children: [
        _CheckRow(label: 'Configurazione salvata', ok: true),
        _CheckRow(
          label: healthOnly
              ? 'Riepilogo salute disponibile'
              : 'Persistenza offline',
          ok: connected,
        ),
        if (!healthOnly)
          _CheckRow(label: 'Scoring dal wearable', ok: connected),
        if (!healthOnly) ...const [
          SizedBox(height: 12),
          _InfoBox(
            icon: Icons.gavel_outlined,
            text:
                'In torneo la companion installata non è un\'autorizzazione. '
                'I rulebook 2026 del CUPRA FIP Tour e di Premier Padel '
                '(6.1.4 D) vietano i dispositivi elettronici dall\'inizio '
                'dello scambio — per Premier Padel dal palleggio di '
                'riscaldamento — fino a fine match, salvo approvazione del '
                'Supervisor o Referee. Chiedi al giudice di gara.',
          ),
        ],
      ],
    ),
  );
}

class _RetiredTizenStep extends StatelessWidget {
  const _RetiredTizenStep({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => _StepShell(
    icon: Icons.update_disabled_outlined,
    title: done ? 'Guida Tizen completata' : 'Tizen non è più distribuibile',
    message:
        'Samsung non accetta nuove app o aggiornamenti Tizen per Galaxy Watch. Momentum non può pubblicare una nuova companion Tizen.',
    child: const Column(
      children: [
        _InfoBox(
          icon: Icons.verified_user_outlined,
          text:
              'Non ti mostreremo pairing o test fittizi. Per lo scoring nativo scegli Galaxy Watch4 o successivo con Wear OS.',
        ),
        SizedBox(height: 12),
        _CheckRow(label: 'Migrazione consigliata: Wear OS', ok: true),
        _CheckRow(label: 'Nuova pubblicazione Tizen', ok: false),
      ],
    ),
  );
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
    this.showIcon = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget child;
  final bool showIcon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (showIcon) ...[
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RallyColors.lime.withValues(alpha: 0.12),
            border: Border.all(color: RallyColors.lime.withValues(alpha: 0.34)),
          ),
          child: Icon(icon, size: 44, color: RallyColors.lime),
        ),
        const SizedBox(height: 22),
      ],
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 9),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white60,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 24),
      child,
    ],
  );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          color: ok ? RallyColors.win : Colors.white38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.success = false,
  });
  final IconData icon;
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? RallyColors.win : RallyColors.lime;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
