/// Paywall (PRD 8): Free / Plus 4,99 / Pro 8,99 / Coach 14,99.
///
/// Store-compliant: clear free path, restore, manage/cancel, no forced plan.
/// Contextual `plan` / `gate` / `reason` only highlight the minimum tier.
///
/// In produzione l'acquisto passa da RevenueCat + IAP store (PRD I5).
/// In debug può usare un'attivazione locale controllata; in release, senza
/// RevenueCat configurato, non abilita piani Premium gratis.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/purchases_service.dart';

final _storePlanInfoProvider = FutureProvider<Map<Plan, StorePlanInfo>>((ref) {
  return PurchasesService.planInfo();
});

String? _requirePaywallBillingUser(
  BuildContext context,
  WidgetRef ref, {
  String? authReturnTo,
}) {
  final userId = cloudClient?.auth.currentUser?.id;
  if (isAuthenticatedBillingUserId(userId) &&
      ref.read(cloudAuthProvider).profileLinked) {
    return userId;
  }
  context.push(
    Uri(
      path: '/auth',
      queryParameters: {
        'returnTo': authReturnTo ?? '/paywall',
      },
    ).toString(),
  );
  return null;
}

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({
    super.key,
    this.recommendedPlan,
    this.gateKey,
    this.reason,
    this.returnTo,
  });

  /// Wire name: free | plus | pro | coach
  final String? recommendedPlan;
  final String? gateKey;
  final String? reason;
  final String? returnTo;

  Plan? get _recommended {
    if (recommendedPlan != null && recommendedPlan!.isNotEmpty) {
      return Plan.fromName(recommendedPlan);
    }
    if (gateKey != null && gates.containsKey(gateKey)) {
      return gates[gateKey!]!.requiredPlan;
    }
    return null;
  }

  String? get _contextPitch {
    if (reason != null && reason!.trim().isNotEmpty) return reason!.trim();
    if (gateKey != null) return gates[gateKey!]?.pitch;
    return null;
  }

  String get _selfLocation {
    return Uri(
      path: '/paywall',
      queryParameters: {
        if (recommendedPlan != null && recommendedPlan!.isNotEmpty)
          'plan': recommendedPlan!,
        if (gateKey != null && gateKey!.isNotEmpty) 'gate': gateKey!,
        if (reason != null && reason!.isNotEmpty) 'reason': reason!,
        if (returnTo != null && returnTo!.isNotEmpty) 'returnTo': returnTo!,
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(entitlementsProvider).plan;
    final storeInfo = ref.watch(_storePlanInfoProvider);
    final planInfo = storeInfo.valueOrNull ?? const <Plan, StorePlanInfo>{};
    final linked = ref.watch(cloudAuthProvider).profileLinked &&
        isAuthenticatedBillingUserId(cloudClient?.auth.currentUser?.id);
    final rec = _recommended;
    final pitch = _contextPitch;
    // Store policy: never force a plan — only highlight the minimum for the gate.
    final highlightPlan = rec ?? Plan.pro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piani e abbonamenti'),
        leading: SafeBackButton(
          fallback: returnTo != null && returnTo!.startsWith('/')
              ? returnTo!
              : AppLocations.profile,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/brand/rallymate_pro_fitness_cover.jpg',
                fit: BoxFit.cover,
                cacheWidth: 1000,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (pitch != null) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec != null
                        ? 'Stai sbloccando funzioni di ${rec.label}'
                        : 'Funzione premium',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pitch,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Punteggio, storico e funzioni Free restano sempre '
                    'disponibili senza abbonamento.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!linked) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account gratuito per acquisti',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Serve un account gratuito collegato per acquistare o '
                    'ripristinare l’abbonamento su tutti i dispositivi '
                    '(requisito App Store / Google Play).',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      context.push(
                        Uri(
                          path: '/auth',
                          queryParameters: {'returnTo': _selfLocation},
                        ).toString(),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Accedi o crea account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!PurchasesService.configured && !_devActivationAllowed) ...[
            const _StoreWarning(
              text:
                  'Prezzi e acquisti non sono disponibili in questa build. '
                  'Le funzioni Free restano utilizzabili senza limitazioni.',
            ),
            const SizedBox(height: 12),
          ],
          _planCard(
            context,
            ref,
            plan: Plan.plus,
            current: current,
            info: planInfo[Plan.plus],
            color: RallyColors.teamThem,
            highlight: highlightPlan == Plan.plus,
            features: const [
              '⌚⌚ Duo Mode: ogni team segna dal proprio smartwatch',
              'Backup cloud e sync multi-device',
              'Analytics avanzate e trend',
              'Momentum Wrapped illimitato + link pubblici',
              'Export PDF dei report',
              'Allenamenti premium',
              'Team illimitati',
            ],
          ),
          const SizedBox(height: 12),
          _planCard(
            context,
            ref,
            plan: Plan.pro,
            current: current,
            info: planInfo[Plan.pro],
            color: RallyColors.lime,
            highlight: highlightPlan == Plan.pro,
            features: const [
              'Tutto di Plus',
              'Pallino Assistant (partite, training e team — senza salute di sistema)',
              'Apple Salute o Google Health Connect per insight fitness',
              'Consigli tattici post-partita e migliori coppie/scontri',
              'Programmi personalizzati e carico allenamento',
              'Difficoltà avversari advanced: upset, imprese, streak',
              'Gruppi amici e classifiche private',
            ],
          ),
          const SizedBox(height: 12),
          _planCard(
            context,
            ref,
            plan: Plan.coach,
            current: current,
            info: planInfo[Plan.coach],
            color: const Color(0xFFB388FF),
            highlight: highlightPlan == Plan.coach,
            features: const [
              'Profilo coach pubblico con certificazioni e specializzazioni',
              'Crea e vendi pacchetti: programmi, schede, lezioni 1:1 e di gruppo',
              'Gestione atleti e assegnazione schede',
              'Progress tracking e report condividibili',
              'Commissioni trasparenti (10-15% in base al tipo)',
              'Visibilità nel marketplace Momentum',
            ],
          ),
          const SizedBox(height: 16),
          if (PurchasesService.configured && storeInfo.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (PurchasesService.configured && storeInfo.hasError)
            const _StoreWarning(
              text:
                  'Prezzi e acquisti sono temporaneamente non disponibili. '
                  'Riprova tra poco.',
            ),
          const SizedBox(height: 8),
          _StoreComplianceFooter(
            ref: ref,
            returnTo: returnTo,
            authReturnTo: _selfLocation,
          ),
        ],
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    WidgetRef ref, {
    required Plan plan,
    required Plan current,
    required StorePlanInfo? info,
    required Color color,
    required List<String> features,
    bool highlight = false,
  }) {
    final active = current == plan;
    final requiresLiveStoreInfo = PurchasesService.configured;
    final storeReady =
        _devActivationAllowed || (requiresLiveStoreInfo && info != null);
    final price =
        info?.displayPrice ?? '€${plan.monthlyEur.toStringAsFixed(2)}';
    final period = info?.periodLabel ?? 'mensile';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlight ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan.label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (highlight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CONSIGLIATO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Abbonamento $period auto-rinnovabile. Nessun acquisto è '
              'necessario per usare punteggio, storico locale e funzioni Free.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white60,
                height: 1.35,
              ),
            ),
            if (requiresLiveStoreInfo && info == null) ...[
              const SizedBox(height: 8),
              const _StoreWarning(
                text:
                    'Questo piano non è temporaneamente acquistabile. '
                    'Le altre funzioni dell’app restano disponibili.',
              ),
            ],
            const SizedBox(height: 12),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(fontSize: 13.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
              ),
              onPressed: active || !storeReady
                  ? null
                  : () => _activate(context, ref, plan),
              child: Text(
                active
                    ? 'Piano attivo'
                    : storeReady
                    ? 'Continua con ${plan.label}'
                    : 'Offerta non disponibile',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _leavePaywall(BuildContext context) {
    final dest = returnTo;
    if (dest != null && dest.startsWith('/')) {
      if (context.canPop()) {
        context.pop();
      }
      context.go(dest);
      return;
    }
    AppNavigation.popOrGo(context, fallback: AppLocations.profile);
  }

  Future<void> _activate(BuildContext context, WidgetRef ref, Plan plan) async {
    if (PurchasesService.configured && plan != Plan.free) {
      final userId = _requirePaywallBillingUser(
        context,
        ref,
        authReturnTo: _selfLocation,
      );
      if (userId == null) return;
      final error = await PurchasesService.purchase(
        plan,
        expectedAppUserId: userId,
      );
      if (error != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
        return;
      }
      final snapshot = await PurchasesService.verifiedActivePlan(userId);
      if (!snapshot.identityVerified ||
          snapshot.appUserId != userId ||
          snapshot.plan == null ||
          cloudClient?.auth.currentUser?.id != userId ||
          !ref.read(cloudAuthProvider).profileLinked) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Acquisto ricevuto, ma account non verificato. '
                'Controlla il piano dal profilo.',
              ),
            ),
          );
        }
        return;
      }
      final kv = ref.read(keyValueRepoProvider);
      await applyVerifiedStorePlan(
        supabaseUserId: userId,
        snapshot: snapshot,
        readAccountRole: () => kv.get('account_role'),
        readCurrentPlan: () async => Plan.fromName(await kv.get('plan')),
        readPremiumOverride: () async =>
            (await kv.get('premium_override')) == 'true',
        allowFreeDowngrade: true,
        writePlan: (storePlan) async {
          if (cloudClient?.auth.currentUser?.id == userId &&
              ref.read(cloudAuthProvider).profileLinked) {
            await kv.set('plan', storePlan.name);
          }
        },
      );
    } else if (plan != Plan.free && !_devActivationAllowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acquisti temporaneamente non disponibili.'),
          ),
        );
      }
      return;
    } else {
      if (plan == Plan.free) {
        await ref.read(keyValueRepoProvider).set('plan', Plan.free.name);
      }
    }
    if (context.mounted) {
      final unlocked = plan == Plan.plus
          ? 'Duo, backup, analytics e team illimitati'
          : plan == Plan.pro
          ? 'Pallino AI, Health Connect e insight avanzati'
          : plan == Plan.coach
          ? 'Strumenti coach e marketplace'
          : 'piano aggiornato';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plan.label} attivo · $unlocked')),
      );
      _leavePaywall(context);
    }
  }

  bool get _devActivationAllowed => CloudConfig.testPremium;
}

class _StoreComplianceFooter extends StatelessWidget {
  const _StoreComplianceFooter({
    required this.ref,
    this.returnTo,
    this.authReturnTo,
  });

  final WidgetRef ref;
  final String? returnTo;
  final String? authReturnTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            final dest = returnTo;
            if (dest != null && dest.startsWith('/')) {
              if (context.canPop()) context.pop();
              context.go(dest);
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.close),
          label: const Text('Continua senza abbonamento'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _restore(context),
          icon: const Icon(Icons.restore),
          label: const Text('Ripristina acquisti'),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () => _openConfigured(
                context,
                CloudConfig.privacyPolicyUrl,
                'Privacy policy non configurata in questa build.',
              ),
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () => _openConfigured(
                context,
                CloudConfig.termsUrl,
                'Termini non configurati in questa build.',
              ),
              child: const Text('Termini'),
            ),
            TextButton(
              onPressed: () => _openUrl(context, _subscriptionManagementUrl),
              child: const Text('Gestisci o disdici'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Il pagamento viene confermato da App Store o Google Play. Puoi '
          'gestire o disdire l’abbonamento dallo store; il piano resta attivo '
          'fino alla fine del periodo già pagato. Non è richiesto alcun '
          'acquisto per usare le funzioni Free.',
          style: TextStyle(fontSize: 12.2, color: Colors.white60, height: 1.35),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _restore(BuildContext context) async {
    final userId = _requirePaywallBillingUser(
      context,
      ref,
      authReturnTo: authReturnTo ?? '/paywall',
    );
    if (userId == null) return;
    final error = await PurchasesService.restore(expectedAppUserId: userId);
    final kv = ref.read(keyValueRepoProvider);
    final snapshot = error == null
        ? await PurchasesService.verifiedActivePlan(userId)
        : const VerifiedStorePlan(plan: null, identityVerified: false);
    if (cloudClient?.auth.currentUser?.id == userId &&
        ref.read(cloudAuthProvider).profileLinked) {
      await applyVerifiedStorePlan(
        supabaseUserId: userId,
        snapshot: snapshot,
        readAccountRole: () => kv.get('account_role'),
        readCurrentPlan: () async => Plan.fromName(await kv.get('plan')),
        readPremiumOverride: () async =>
            (await kv.get('premium_override')) == 'true',
        allowFreeDowngrade: true,
        writePlan: (storePlan) async {
          if (cloudClient?.auth.currentUser?.id == userId &&
              ref.read(cloudAuthProvider).profileLinked) {
            await kv.set('plan', storePlan.name);
          }
        },
      );
    }
    if (!context.mounted) return;
    final storePlan = snapshot.identityVerified ? snapshot.plan : null;
    final message =
        error ??
        (storePlan == null || storePlan == Plan.free
            ? 'Acquisti verificati. Nessun abbonamento attivo trovato.'
            : 'Acquisti ripristinati: piano ${storePlan.label} attivo.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openConfigured(
    BuildContext context,
    String url,
    String fallbackMessage,
  ) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fallbackMessage)));
      return;
    }
    await _openUrl(context, url);
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link non apribile. Riprova.')),
      );
    }
  }

  String get _subscriptionManagementUrl {
    if (!kDebugMode && Platform.isIOS) {
      return 'https://apps.apple.com/account/subscriptions';
    }
    if (!kDebugMode && Platform.isAndroid) {
      return 'https://play.google.com/store/account/subscriptions';
    }
    if (Platform.isIOS) return 'https://apps.apple.com/account/subscriptions';
    return 'https://play.google.com/store/account/subscriptions';
  }
}

class _StoreWarning extends StatelessWidget {
  const _StoreWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RallyColors.loss.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RallyColors.loss.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: RallyColors.loss),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
