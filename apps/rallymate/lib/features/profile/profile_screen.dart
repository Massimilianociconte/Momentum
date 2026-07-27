/// Profilo + impostazioni: piano, watch sync, privacy.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation_targets.dart';
import '../../core/profile_visuals.dart';
import '../../core/providers.dart';
import '../../core/paywall_nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/database.dart';
import '../../domain/entitlements.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';
import '../../services/cloud/push_registration_service.dart';
import '../../services/cloud/purchases_service.dart';
import '../../services/health_connect.dart';
import '../../services/notifications.dart';
import '../../services/watch_sync.dart';
import '../../services/wearable_match_dispatcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.focus});

  final ProfileSectionTarget? focus;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();
  final _sectionKeys = {
    for (final section in ProfileSectionTarget.values) section: GlobalKey(),
  };
  Timer? _highlightTimer;
  ProfileSectionTarget? _highlighted;

  @override
  void initState() {
    super.initState();
    _scheduleFocusedSection();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) _scheduleFocusedSection();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleFocusedSection() {
    final focus = widget.focus;
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _sectionKeys[focus]?.currentContext;
      if (targetContext == null) return;
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.06,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() => _highlighted = focus);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _highlighted = null);
      });
    });
  }

  Widget _sectionAnchor(ProfileSectionTarget section, Widget child) {
    final highlighted = _highlighted == section;
    return Semantics(
      container: true,
      label: section.label,
      child: AnimatedContainer(
        key: _sectionKeys[section],
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: highlighted
              ? RallyColors.glow(RallyColors.lime, blur: 24)
              : const [],
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final ents = ref.watch(entitlementsProvider);

    final children = <Widget>[
      _ProfileHero(me: me, ents: ents),
      const SizedBox(height: 12),
      _ProfileQuickActionsCard(plan: ents.plan),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.plan, const _StoreAccountCard()),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.visibility, const _VisibilityCard()),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.smartwatch, const _SmartwatchCard()),
      const SizedBox(height: 12),
      _sectionAnchor(
        ProfileSectionTarget.notifications,
        const _NotificationsCard(),
      ),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.health, const _HealthConnectCard()),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.account, const _AccountCard()),
      const SizedBox(height: 12),
      _sectionAnchor(ProfileSectionTarget.backup, _DataBackupCard(ents: ents)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: widget.focus == null
          ? ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              // ignore: deprecated_member_use
              cacheExtent: 240,
              children: children,
            )
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
    );
  }
}

class _SmartwatchCard extends ConsumerWidget {
  const _SmartwatchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(watchSyncProvider);
    final devices =
        ref.watch(connectedDevicesProvider).valueOrNull ?? const [];
    final readyDevice = devices.where(isScoringWearableReady).firstOrNull;
    final anyReady = readyDevice != null;
    final label = anyReady
        ? 'Pronto per la partita (${readyDevice.displayName.isNotEmpty ? readyDevice.displayName : readyDevice.platform})'
        : watch.companionInstalled || watch.paired
        ? 'Companion rilevata — completa la verifica guidata'
        : devices.isNotEmpty
        ? 'Dispositivo registrato — verifica ancora necessaria'
        : 'Companion da configurare';
    final iconOk = anyReady || watch.connected;
    return SectionCard(
      title: 'SMARTWATCH',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                iconOk ? Icons.watch : Icons.watch_off,
                color: anyReady
                    ? RallyColors.win
                    : (iconOk ? RallyColors.teamGold : Colors.white38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Verifica installazione, comunicazione e feedback aptico con una '
            'procedura guidata. I dati del dispositivo restano locali.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push(
              anyReady ? '/devices' : '/devices/setup',
            ),
            icon: const Icon(Icons.settings_input_component, size: 18),
            label: Text(
              anyReady ? 'Gestisci dispositivi' : 'Configura smartwatch',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.me, required this.ents});

  final Player? me;
  final Entitlements ents;

  @override
  Widget build(BuildContext context) {
    final name = me?.name.isNotEmpty == true ? me!.name : 'Giocatore';
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push('/profile/edit'),
      child: _heroBody(name),
    );
  }

  Widget _heroBody(String name) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RallyColors.surfaceHigh, RallyColors.surface],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          PlayerAvatar(player: me, size: 66),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _PlanBadge(
                      plan: ents.plan,
                      testAccount: ents.premiumOverride,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    _roleLabel(me?.preferredRole ?? 'UNDEFINED'),
                    _levelLabel(me?.level ?? ''),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniBadge(
                      icon: Icons.privacy_tip_outlined,
                      label: _privacyLabel(me?.privacy ?? 'PRIVATE'),
                    ),
                    const SizedBox(width: 8),
                    _MiniBadge(
                      icon: Icons.sports_tennis,
                      label: _handLabel(me?.dominantHand ?? 'RIGHT'),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileQuickActionsCard extends StatelessWidget {
  const _ProfileQuickActionsCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.workspace_premium,
              color: RallyColors.lime,
            ),
            title: const Text('Piano e vantaggi'),
            subtitle: Text(
              plan == Plan.free
                  ? 'Free attivo · Plus/Pro sbloccano backup e insight'
                  : '${plan.label} attivo',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushPaywall(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.travel_explore_outlined),
            title: const Text('Social e matchmaking'),
            subtitle: const Text('Trova giocatori compatibili in zona'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/social'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Amici e richieste'),
            subtitle: const Text('Inviti, QR, contatti e giocatori bloccati'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/friends'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('I miei team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/teams'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Regolamento e Pallino'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/rules'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: RallyColors.lime),
            title: const Text('Pallino Assistant'),
            subtitle: const Text('Aiuto app, backup, social e consigli d’uso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              Uri(
                path: '/pro-chat',
                queryParameters: const {
                  'mode': 'APP_HELP',
                  'q': 'Come posso usare al meglio Momentum con il mio piano?',
                },
              ).toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends ConsumerWidget {
  const _VisibilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final current = me?.privacy ?? 'PRIVATE';
    return SectionCard(
      title: 'VISIBILITÀ SOCIAL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scegli quanto farti trovare. Il social usa solo dati essenziali: '
            'nome pubblico, livello, ruolo, disponibilità e distanza indicativa.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'PRIVATE',
                label: Text('Privato'),
                icon: Icon(Icons.lock_outline),
              ),
              ButtonSegment(
                value: 'FRIENDS',
                label: Text('Amici'),
                icon: Icon(Icons.group_outlined),
              ),
              ButtonSegment(
                value: 'PUBLIC',
                label: Text('Pubblico'),
                icon: Icon(Icons.public),
              ),
            ],
            selected: {current},
            onSelectionChanged: (next) async {
              await ref.read(playerRepoProvider).updatePrivacy(next.first);
              ref.invalidate(meProvider);
              // Propaga al cloud se loggato (best-effort, non bloccante).
              unawaited(
                ref.read(cloudAuthProvider.notifier).maybeSyncBasicProfile(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Visibilità: ${_privacyLabel(next.first)}'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/social'),
            icon: const Icon(Icons.travel_explore_outlined, size: 18),
            label: const Text('Apri mappa giocatori'),
          ),
        ],
      ),
    );
  }
}

class _StoreAccountCard extends ConsumerStatefulWidget {
  const _StoreAccountCard();

  @override
  ConsumerState<_StoreAccountCard> createState() => _StoreAccountCardState();
}

class _StoreAccountCardState extends ConsumerState<_StoreAccountCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(entitlementsProvider).plan;
    return SectionCard(
      title: 'ABBONAMENTO E ACQUISTI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan == Plan.free
                    ? Icons.workspace_premium_outlined
                    : Icons.workspace_premium,
                color: plan == Plan.free ? Colors.white54 : RallyColors.lime,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan == Plan.free
                      ? 'Piano Free attivo'
                      : 'Piano ${plan.label} attivo',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Gli acquisti Premium sono gestiti solo dallo store ufficiale. Puoi '
            'ripristinare un acquisto precedente o aprire la gestione '
            'abbonamenti senza passare dal paywall.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _restorePurchases,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore, size: 18),
                  label: const Text('Ripristina'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(_subscriptionManagementUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Gestisci'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() => _busy = true);
    final userId = cloudClient?.auth.currentUser?.id;
    if (userId == null ||
        !isAuthenticatedBillingUserId(userId) ||
        !ref.read(cloudAuthProvider).profileLinked) {
      if (mounted) {
        setState(() => _busy = false);
        context.push(
          Uri(
            path: '/auth',
            queryParameters: {
              'returnTo': AppLocations.profileSection(
                ProfileSectionTarget.plan,
              ),
            },
          ).toString(),
        );
      }
      return;
    }
    final error = await PurchasesService.restore(expectedAppUserId: userId);
    final snapshot = error == null
        ? await PurchasesService.verifiedActivePlan(userId)
        : const VerifiedStorePlan(plan: null, identityVerified: false);
    if (cloudClient?.auth.currentUser?.id == userId &&
        ref.read(cloudAuthProvider).profileLinked) {
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
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final storePlan = snapshot.identityVerified ? snapshot.plan : null;
    final message =
        error ??
        (storePlan == null || storePlan == Plan.free
            ? 'Acquisti verificati. Nessun abbonamento Premium attivo trovato.'
            : 'Acquisti ripristinati: piano ${storePlan.label} attivo.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link non apribile. Riprova.')),
      );
    }
  }

  String get _subscriptionManagementUrl {
    if (Platform.isIOS) return 'https://apps.apple.com/account/subscriptions';
    return 'https://play.google.com/store/account/subscriptions';
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan, this.testAccount = false});

  final Plan plan;

  /// Account con premium_override (§11): il badge lo rende riconoscibile
  /// a colpo d'occhio, senza spacciarlo per abbonamento reale.
  final bool testAccount;

  @override
  Widget build(BuildContext context) {
    final paid = plan != Plan.free || testAccount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: paid ? RallyColors.lime.withValues(alpha: 0.18) : Colors.white10,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        testAccount ? '${plan.label} · TEST' : plan.label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: paid ? RallyColors.lime : Colors.white60,
        ),
      ),
    );
  }
}

class _DataBackupCard extends StatelessWidget {
  const _DataBackupCard({required this.ents});

  final Entitlements ents;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'DATI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Il piano Free salva tutto sul dispositivo e sincronizza solo il '
            'profilo base se accedi. Il backup completo multi-device è Plus.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (!ents.cloudBackup)
            _SoftCta(
              icon: Icons.cloud_done_outlined,
              title: 'Backup dati completo',
              subtitle: 'Partite, team, log allenamenti e ripristino device.',
              label: 'Scopri Plus',
              onTap: () => pushPaywall(context),
            )
          else
            _SoftCta(
              icon: Icons.cloud_done,
              title: 'Backup Plus attivo',
              subtitle: 'Backup e ripristino dalla pagina account.',
              label: 'Gestisci account',
              onTap: () => context.push('/auth'),
              success: true,
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/privacy'),
            icon: const Icon(Icons.privacy_tip_outlined, size: 18),
            label: const Text('Privacy e dati'),
          ),
        ],
      ),
    );
  }
}

class _SoftCta extends StatelessWidget {
  const _SoftCta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
    this.success = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onTap;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? RallyColors.win : RallyColors.lime;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.2,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

String _roleLabel(String wire) => switch (wire) {
  'LEFT' => 'Giocatore di sinistra',
  'RIGHT' => 'Giocatore di destra',
  'FLEX' => 'Flex',
  _ => 'Ruolo da definire',
};

String _levelLabel(String wire) => switch (wire) {
  'BEGINNER' => 'Principiante',
  'IMPROVER' => 'In crescita',
  'INTERMEDIATE' => 'Intermedio',
  'ADVANCED' => 'Avanzato',
  'COMPETITION' => 'Agonista',
  _ => '',
};

String _privacyLabel(String wire) => switch (wire) {
  'PUBLIC' => 'Pubblico',
  'FRIENDS' => 'Solo amici',
  _ => 'Privato',
};

String _handLabel(String wire) => switch (wire) {
  'LEFT' => 'Mancino',
  _ => 'Destro',
};

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(notificationPermissionProvider);
    return SectionCard(
      title: 'NOTIFICHE',
      child: permission.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => const Text(
          'Notifiche non disponibili su questo dispositivo.',
          style: TextStyle(fontSize: 12.5, color: Colors.white54, height: 1.4),
        ),
        data: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.granted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: state.granted ? RallyColors.win : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Momentum usa le notifiche per richieste, inviti e promemoria '
              'scelti da te. Non invia aggiornamenti continui del punteggio e '
              'puoi disattivarle dalle impostazioni di sistema.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.granted || !state.canRequest
                      ? null
                      : () async {
                          final next = await ref
                              .read(notificationServiceProvider)
                              .requestPermission();
                          if (next.granted) {
                            await ref
                                .read(pushRegistrationServiceProvider)
                                .sync(force: true);
                          }
                          ref.invalidate(notificationPermissionProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Notifiche: ${next.label}'),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.notifications),
                  label: Text(state.granted ? 'Autorizzate' : 'Attiva'),
                ),
                OutlinedButton.icon(
                  onPressed: state.granted
                      ? () async {
                          final ok = await ref
                              .read(notificationServiceProvider)
                              .scheduleWeeklyRecap(
                                DateTime.now().add(const Duration(minutes: 2)),
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Promemoria programmato'
                                      : 'Notifica non programmata',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Prova promemoria'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthConnectCard extends ConsumerStatefulWidget {
  const _HealthConnectCard();

  @override
  ConsumerState<_HealthConnectCard> createState() => _HealthConnectCardState();
}

class _HealthConnectCardState extends ConsumerState<_HealthConnectCard>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(minutes: 5);

  HealthConnectSummary? _summary;
  bool _busy = false;
  bool _initialRefreshScheduled = false;
  DateTime? _lastRefreshedAt;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _refreshTodayIfAllowed(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTodayIfAllowed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ents = ref.watch(entitlementsProvider);
    final status = ref.watch(healthConnectStatusProvider);

    if (!ents.healthConnectSync) {
      return SectionCard(
        title: 'FITNESS PRO',
        child: _SoftCta(
          icon: Icons.health_and_safety_outlined,
          title: 'Insight fitness avanzati',
          subtitle:
              '${HealthConnectService.providerName} importa solo dati '
              'aggregati utili al recupero e alle statistiche post-partita.',
          label: 'Passa a Pro',
          onTap: () => pushPaywall(context),
        ),
      );
    }

    final provider = HealthConnectService.providerName;
    return SectionCard(
      title: provider.toUpperCase(),
      child: status.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => _healthUnavailable(),
        data: (s) {
          final accessLabel = s.granted && HealthConnectService.isApple
              ? 'Accesso configurato'
              : s.label;
          if (!HealthConnectService.supportedPlatform) {
            return _healthUnavailable(
              'Disponibile su Android (Google Health Connect) e iOS '
              '(Apple Salute).',
            );
          }
          if (!s.available) {
            return _healthUnavailable(
              s.availability == 'updateRequired'
                  ? 'Aggiorna o installa Health Connect per collegare i dati fitness.'
                  : '$provider non risulta disponibile su questo dispositivo.',
            );
          }
          if (s.granted &&
              _summary == null &&
              !_busy &&
              !_initialRefreshScheduled) {
            _initialRefreshScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _refreshTodayIfAllowed();
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    s.granted
                        ? Icons.health_and_safety
                        : Icons.health_and_safety_outlined,
                    color: s.granted ? RallyColors.win : Colors.white38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      accessLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Momentum legge passi, calorie attive, minuti di esercizio e '
                'frequenza cardiaca media. I permessi sono separati e restano '
                'revocabili da ${HealthConnectService.isApple ? 'Impostazioni → Salute; Apple mostra lì lo stato dei singoli accessi di lettura' : 'Health Connect'}.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: s.granted || _busy
                        ? null
                        : _requestHealthPermissions,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(s.granted ? accessLabel : 'Collega'),
                  ),
                  OutlinedButton.icon(
                    onPressed: s.granted && !_busy ? _readToday : null,
                    icon: const Icon(Icons.query_stats, size: 18),
                    label: const Text('Aggiorna oggi'),
                  ),
                ],
              ),
              if (_summary != null) ...[
                const SizedBox(height: 10),
                _HealthSummaryStrip(summary: _summary!),
                if (_lastRefreshedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Oggi, aggiornato alle '
                    '${TimeOfDay.fromDateTime(_lastRefreshedAt!).format(context)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _healthUnavailable([String? message]) => Text(
    message ?? 'Health Connect non disponibile su questa piattaforma.',
    style: const TextStyle(fontSize: 12.5, color: Colors.white54, height: 1.4),
  );

  Future<void> _requestHealthPermissions() async {
    setState(() => _busy = true);
    final next = await ref
        .read(healthConnectServiceProvider)
        .requestPermissions();
    ref.invalidate(healthConnectStatusProvider);
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${HealthConnectService.providerName}: '
            '${next.granted && HealthConnectService.isApple ? 'accesso configurato' : next.label}',
          ),
        ),
      );
    }
    if (next.granted) {
      await _readToday();
    }
  }

  Future<void> _refreshTodayIfAllowed() async {
    if (!mounted || _busy) return;
    // Il timer da 5 minuti continua a girare anche ad app in background:
    // lì la lettura Health è solo consumo. Il rientro in foreground
    // riaggiorna subito via didChangeAppLifecycleState.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final entitlements = ref.read(entitlementsProvider);
    final status = ref.read(healthConnectStatusProvider).value;
    if (!entitlements.healthConnectSync || status?.granted != true) return;
    await _readToday();
  }

  Future<void> _readToday() async {
    if (_busy) return;
    setState(() => _busy = true);
    final summary = await ref.read(healthConnectServiceProvider).readToday();
    if (mounted) {
      setState(() {
        if (summary != null) {
          _summary = summary;
          _lastRefreshedAt = DateTime.now();
        }
        _busy = false;
      });
    }
  }
}

class _HealthSummaryStrip extends StatelessWidget {
  const _HealthSummaryStrip({required this.summary});

  final HealthConnectSummary summary;

  @override
  Widget build(BuildContext context) {
    final bpm = summary.averageHeartRateBpm;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric('${summary.steps}', 'passi'),
        _metric(summary.activeCaloriesKcal.toStringAsFixed(0), 'kcal'),
        _metric('${summary.exerciseMinutes}', 'min'),
        _metric(bpm == null ? '-' : bpm.toStringAsFixed(0), 'bpm medi'),
      ],
    );
  }

  Widget _metric(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: RallyColors.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    ),
  );
}

/// Account cloud (PRD 5.1 cloud "solo dove necessario"): la card è un
/// riassunto; login, registrazione, sync e logout vivono in /auth.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(cloudAuthProvider);
    final ents = ref.watch(entitlementsProvider);

    if (!CloudConfig.supabaseConfigured) {
      return const SectionCard(
        title: 'ACCOUNT GRATUITO',
        child: Text(
          'I servizi account non sono disponibili in questa versione. '
          'Scoring, storico e allenamenti restano utilizzabili in locale; '
          'account, social e backup si riattivano con una build configurata.',
          style: TextStyle(fontSize: 12.5, color: Colors.white54, height: 1.4),
        ),
      );
    }

    if (!auth.signedIn) {
      return SectionCard(
        title: 'ACCOUNT GRATUITO',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crea un account gratuito per salvare profilo base, preferenze '
              'e continuità personale. Il backup completo resta una funzione '
              'Plus/Pro separata.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _SoftCta(
              icon: Icons.person_add_alt_1,
              title: 'Continuità base',
              subtitle: 'Nome, livello, ruolo e privacy profilo sincronizzati.',
              label: 'Crea account',
              onTap: () => context.push('/auth?mode=signup'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/auth'),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Ho già un account'),
            ),
          ],
        ),
      );
    }

    if (!auth.profileLinked) {
      return SectionCard(
        title: 'ACCOUNT DA COLLEGARE',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${auth.email ?? 'La sessione cloud'} è attiva, ma i dati '
              'locali non sono ancora associati. Restano intatti sul '
              'dispositivo finché non confermi il collegamento.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push('/auth'),
              icon: const Icon(Icons.link),
              label: const Text('Collega senza perdere dati'),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      title: 'ACCOUNT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: RallyColors.win, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  auth.email ?? 'Account attivo',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SoftCta(
            icon: Icons.manage_accounts,
            title: 'Gestisci account',
            subtitle:
                'Email, sync profilo base, backup completo (Plus), logout e recupero.',
            label: 'Apri',
            onTap: () => context.push('/auth'),
            success: true,
          ),
          if (ents.coachTools) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push('/coach'),
              icon: const Icon(Icons.sports),
              label: const Text('Area Coach'),
            ),
          ],
        ],
      ),
    );
  }
}
