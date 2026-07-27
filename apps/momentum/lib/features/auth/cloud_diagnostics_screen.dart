library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';

/// Development-only cloud checks. It deliberately never renders API keys,
/// access tokens, refresh tokens or full user identifiers.
class CloudDiagnosticsScreen extends ConsumerStatefulWidget {
  const CloudDiagnosticsScreen({super.key});

  @override
  ConsumerState<CloudDiagnosticsScreen> createState() =>
      _CloudDiagnosticsScreenState();
}

class _CloudDiagnosticsScreenState
    extends ConsumerState<CloudDiagnosticsScreen> {
  AssistantHealth? _health;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostica')),
        body: const Center(child: Text('Disponibile solo nelle build Debug.')),
      );
    }

    final auth = ref.watch(cloudAuthProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final projectRef = CloudConfig.supabaseConfigured
        ? Uri.tryParse(CloudConfig.supabaseUrl)?.host.split('.').first ?? '-'
        : '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostica cloud')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            title: 'BUILD',
            child: Column(
              children: [
                _DiagnosticRow(
                  label: 'Configurazione client',
                  value: CloudConfig.validation.isValid ? 'Valida' : 'Assente',
                  ok: CloudConfig.validation.isValid,
                ),
                _DiagnosticRow(label: 'Progetto', value: projectRef),
                _DiagnosticRow(
                  label: 'Runtime Supabase',
                  value: cloudRuntimeStatus.name,
                  ok: cloudRuntimeStatus == CloudRuntimeStatus.ready,
                ),
                if (cloudInitializationError != null)
                  _DiagnosticRow(
                    label: 'Errore init',
                    value: cloudInitializationError!,
                    ok: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'SESSIONE',
            child: Column(
              children: [
                _DiagnosticRow(
                  label: 'Autenticato',
                  value: auth.signedIn ? 'Sì' : 'No',
                  ok: auth.signedIn,
                ),
                _DiagnosticRow(label: 'Utente', value: _maskedId(auth.userId)),
                _DiagnosticRow(
                  label: 'Email verificata',
                  value: auth.emailConfirmed ? 'Sì' : 'No',
                  ok: auth.emailConfirmed,
                ),
                _DiagnosticRow(
                  label: 'Profilo locale/cloud',
                  value: auth.profileLinkStatus.name,
                  ok: auth.profileLinked,
                ),
                _DiagnosticRow(
                  label: 'Entitlement',
                  value: entitlements.plan.label,
                  ok: entitlements.llmAssistant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'EDGE FUNCTION ASSISTANT',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_health != null) ...[
                  _DiagnosticRow(
                    label: 'Raggiungibile',
                    value: _health!.reachable ? 'Sì' : 'No',
                    ok: _health!.reachable,
                  ),
                  _DiagnosticRow(
                    label: 'JWT accettato',
                    value: _health!.authenticated ? 'Sì' : 'No',
                    ok: _health!.authenticated,
                  ),
                  _DiagnosticRow(
                    label: 'Provider AI server-side',
                    value: _health!.providerConfigured
                        ? 'Pronto'
                        : 'Non pronto',
                    ok: _health!.providerConfigured,
                  ),
                  if (_health!.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _health!.error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: RallyColors.loss,
                        ),
                      ),
                    ),
                ] else
                  const Text(
                    'Il test usa la sessione corrente e restituisce solo stati '
                    'booleani. Nessun secret viene letto dal client.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _testAssistant,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: const Text('Esegui test sicuro'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: !auth.signedIn || _busy ? null : _clearTestSession,
            icon: const Icon(Icons.logout),
            label: const Text('Cancella solo la sessione di test'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAssistant() async {
    setState(() => _busy = true);
    final health = await AssistantClient.health();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _health = health;
    });
  }

  Future<void> _clearTestSession() async {
    setState(() => _busy = true);
    await ref.read(cloudAuthProvider.notifier).signOut();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _health = null;
    });
    context.go('/auth');
  }

  String _maskedId(String? id) {
    if (id == null || id.isEmpty) return '-';
    if (id.length < 10) return '***';
    return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value, this.ok});

  final String label;
  final String value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
          ),
          if (ok != null) ...[
            Icon(
              ok! ? Icons.check_circle_outline : Icons.error_outline,
              color: ok! ? RallyColors.win : RallyColors.loss,
              size: 16,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
