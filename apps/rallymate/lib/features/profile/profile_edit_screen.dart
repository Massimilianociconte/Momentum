/// Dedicated profile editor.
///
/// Kept separate from first-run onboarding so editing the account is a stable
/// secondary screen, with a simpler tree and no onboarding-only page machinery.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/providers.dart';
import '../../core/profile_visuals.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../services/profile_image_service.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _goal = TextEditingController();
  final _club = TextEditingController();
  final _area = TextEditingController();
  final _bio = TextEditingController();
  final _preferredTime = TextEditingController();
  DominantHand _hand = DominantHand.rightHand;
  PadelRole _role = PadelRole.undefined;
  PlayerLevel _level = PlayerLevel.intermediate;
  String _side = 'UNDEFINED';
  var _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _goal.dispose();
    _club.dispose();
    _area.dispose();
    _bio.dispose();
    _preferredTime.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final me = await ref.read(playerRepoProvider).me();
    if (me == null || !mounted) return;
    setState(() {
      _name.text = me.name == 'Giocatore' ? '' : me.name;
      _nickname.text = me.nickname;
      _goal.text = me.goal;
      _club.text = me.clubs;
      _area.text = me.homeArea;
      _bio.text = me.bio;
      _preferredTime.text = me.preferredTime;
      _hand = DominantHand.fromWire(me.dominantHand);
      _role = PadelRole.fromWire(me.preferredRole);
      _level = PlayerLevel.fromWire(me.level);
      _side = me.preferredSide;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_name.text.trim().isEmpty) _name.text = 'Giocatore';
      await ref
          .read(playerRepoProvider)
          .saveMe(
            name: _name.text.trim(),
            nickname: _nickname.text.trim(),
            hand: _hand,
            role: _role,
            level: _level,
            goal: _goal.text.trim(),
            clubs: _club.text.trim(),
            homeArea: _area.text.trim(),
            bio: _bio.text.trim(),
            preferredSide: _side,
            preferredTime: _preferredTime.text.trim(),
          );
      await ref.read(keyValueRepoProvider).set('onboarding_done', 'true');
      ref.read(onboardingDoneProvider.notifier).state = true;
      ref.invalidate(meProvider);
      unawaited(ref.read(cloudAuthProvider.notifier).maybeSyncBasicProfile());
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 24 + MediaQuery.viewInsetsOf(context).bottom;
    final auth = ref.watch(cloudAuthProvider);
    final me = ref.watch(meProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifica profilo')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: RallyColors.nightGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
            children: [
              const _EditorIntro(),
              const SizedBox(height: 12),
              _ProfilePhotoEditor(player: me),
              const SizedBox(height: 12),
              _EditorCard(
                title: 'Account ed email',
                subtitle: auth.signedIn
                    ? 'L’email protegge accesso e recupero account. Non è '
                          'visibile agli altri giocatori.'
                    : 'Puoi creare un account gratuito con email. Il profilo '
                          'locale continua a funzionare anche senza login.',
                child: _AccountEditorContent(auth: auth),
              ),
              const SizedBox(height: 12),
              _EditorCard(
                title: 'Identita giocatore',
                subtitle:
                    'Questi dati personalizzano home, team, training e social.',
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: 'Nickname (opzionale)',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _EditorCard(
                title: 'Stile di gioco',
                subtitle:
                    'Ruolo e mano dominante aiutano Padelandia a suggerire esercizi piu utili.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MiniLabel('MANO DOMINANTE'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoicePill(
                            selected: _hand == DominantHand.rightHand,
                            icon: Icons.pan_tool_alt_outlined,
                            label: 'Destra',
                            onTap: () =>
                                setState(() => _hand = DominantHand.rightHand),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChoicePill(
                            selected: _hand == DominantHand.leftHand,
                            icon: Icons.back_hand_outlined,
                            label: 'Sinistra',
                            onTap: () =>
                                setState(() => _hand = DominantHand.leftHand),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _MiniLabel('RUOLO PREFERITO'),
                    const SizedBox(height: 8),
                    _RoleTile(
                      selected: _role == PadelRole.left,
                      title: 'Sinistra',
                      subtitle: 'Chiusura, bandeja, smash',
                      onTap: () => setState(() => _role = PadelRole.left),
                    ),
                    _RoleTile(
                      selected: _role == PadelRole.right,
                      title: 'Destra',
                      subtitle: 'Regia, difesa, continuita',
                      onTap: () => setState(() => _role = PadelRole.right),
                    ),
                    _RoleTile(
                      selected: _role == PadelRole.flex,
                      title: 'Flex',
                      subtitle: 'Ti adatti a partner e partita',
                      onTap: () => setState(() => _role = PadelRole.flex),
                    ),
                    _RoleTile(
                      selected: _role == PadelRole.undefined,
                      title: 'Non lo so ancora',
                      subtitle: 'Lo capirai con le prime statistiche',
                      onTap: () => setState(() => _role = PadelRole.undefined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _EditorCard(
                title: 'Livello e obiettivo',
                subtitle:
                    'Bastano pochi dati: il resto lo costruiremo dalle tue partite.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final level in PlayerLevel.values)
                      _RoleTile(
                        selected: _level == level,
                        title: _levelLabel(level),
                        subtitle: _levelSubtitle(level),
                        onTap: () => setState(() => _level = level),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _goal,
                      decoration: const InputDecoration(
                        labelText: 'Obiettivo (opzionale)',
                        prefixIcon: Icon(Icons.track_changes),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _EditorCard(
                title: 'Social e matchmaking',
                subtitle:
                    'Dati facoltativi. Scegli tu cosa rendere visibile in Privacy e dati.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _area,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Zona approssimativa',
                        hintText: 'Es. Milano nord',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        helperText: 'Non inserire indirizzi precisi.',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _club,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Centro padel abituale',
                        prefixIcon: Icon(Icons.stadium_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _preferredTime,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Fascia oraria preferita',
                        hintText: 'Es. feriali dopo le 19',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _MiniLabel('LATO PREFERITO'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in const [
                          ('LEFT', 'Sinistra'),
                          ('RIGHT', 'Destra'),
                          ('FLEX', 'Flex'),
                          ('UNDEFINED', 'Da definire'),
                        ])
                          ChoiceChip(
                            label: Text(option.$2),
                            selected: _side == option.$1,
                            onSelected: (_) =>
                                setState(() => _side = option.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      maxLength: 180,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio sportiva',
                        hintText: 'Come giochi e che tipo di partita cerchi',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Salvataggio...' : 'Salva profilo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(PlayerLevel level) => switch (level) {
    PlayerLevel.beginner => 'Principiante',
    PlayerLevel.improver => 'In crescita',
    PlayerLevel.intermediate => 'Intermedio',
    PlayerLevel.advanced => 'Avanzato',
    PlayerLevel.competition => 'Agonista',
  };

  String _levelSubtitle(PlayerLevel level) => switch (level) {
    PlayerLevel.beginner => 'Stai costruendo le basi',
    PlayerLevel.improver => 'Giochi gia, vuoi continuita',
    PlayerLevel.intermediate => 'Partite regolari e obiettivi chiari',
    PlayerLevel.advanced => 'Cerchi precisione e vantaggio tattico',
    PlayerLevel.competition => 'Allenamento e match competitivi',
  };
}

class _ProfilePhotoEditor extends ConsumerStatefulWidget {
  const _ProfilePhotoEditor({required this.player});

  final Player? player;

  @override
  ConsumerState<_ProfilePhotoEditor> createState() =>
      _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends ConsumerState<_ProfilePhotoEditor> {
  var _busy = false;
  var _lostSelectionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.player != null && !_lostSelectionChecked) {
        _lostSelectionChecked = true;
        unawaited(_recoverLostSelection());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ProfilePhotoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_lostSelectionChecked && widget.player != null) {
      _lostSelectionChecked = true;
      unawaited(_recoverLostSelection());
    }
  }

  Future<void> _recoverLostSelection() async {
    final player = widget.player;
    if (player == null) return;
    final result = await ref
        .read(profileImageServiceProvider)
        .recoverLostSelection(player);
    if (result != null && mounted) _showResult(result);
  }

  Future<void> _pick(ProfileImageSource source) async {
    final player = widget.player;
    if (_busy || player == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(profileImageServiceProvider)
          .pickAndSave(player, source);
      if (!mounted || result.cancelled) return;
      _showResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final player = widget.player;
    if (_busy || player == null || player.avatarLocalPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere la foto?'),
        content: const Text(
          'Torneranno visibili le iniziali. Se esiste una copia cloud, verrà rimossa in sicurezza.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final message = await ref
          .read(profileImageServiceProvider)
          .remove(player);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Foto profilo rimossa.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(ProfileImageResult result) {
    final message =
        result.message ??
        (result.saved ? 'Foto profilo aggiornata.' : 'Foto non aggiornata.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final entitlement = ref.watch(entitlementsProvider);
    final auth = ref.watch(cloudAuthProvider);
    final cloudReady = entitlement.cloudBackup && auth.profileLinked;
    return _EditorCard(
      title: 'Foto profilo',
      subtitle: cloudReady
          ? 'Ottimizzata sul dispositivo e protetta nel backup multi-device.'
          : 'Resta solo su questo dispositivo. Il backup multi-device è una funzione Premium.',
      child: Column(
        children: [
          Row(
            children: [
              PlayerAvatar(player: player, size: 82),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player?.avatarLocalPath == null
                          ? 'Aggiungi una foto riconoscibile'
                          : 'Foto pronta',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          cloudReady
                              ? Icons.cloud_done_outlined
                              : Icons.smartphone_outlined,
                          size: 16,
                          color: cloudReady ? RallyColors.win : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloudReady ? 'Backup Premium' : 'Solo locale',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || player == null
                      ? null
                      : () => _pick(ProfileImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Galleria', maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || player == null
                      ? null
                      : () => _pick(ProfileImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Fotocamera', maxLines: 1),
                  ),
                ),
              ),
              if (player?.avatarLocalPath != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Rimuovi foto',
                  onPressed: _busy ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

class _AccountEditorContent extends ConsumerWidget {
  const _AccountEditorContent({required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CloudConfig.supabaseConfigured) {
      return const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.white54),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Servizio account non configurato in questa build.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      );
    }

    if (!auth.signedIn) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push('/auth?mode=signup'),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Crea account'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Accedi a un account esistente',
            onPressed: () => context.push('/auth'),
            icon: const Icon(Icons.login),
          ),
        ],
      );
    }

    if (!auth.profileLinked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'La sessione è attiva, ma questo profilo locale non è ancora '
            'collegato. Nessun dato verrà caricato finché non confermi.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/auth'),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Collega profilo locale'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(
              auth.emailConfirmed
                  ? Icons.verified_user_outlined
                  : Icons.mark_email_unread_outlined,
              color: auth.emailConfirmed
                  ? RallyColors.win
                  : RallyColors.teamGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.email ?? 'Account attivo',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    auth.emailConfirmed
                        ? 'Email verificata'
                        : 'Verifica email in attesa',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/auth'),
            icon: const Icon(Icons.manage_accounts_outlined, size: 18),
            label: const Text('Gestisci email e account'),
          ),
        ),
      ],
    );
  }
}

class _EditorIntro extends StatelessWidget {
  const _EditorIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RallyColors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_circle_outlined, color: RallyColors.lime),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aggiorna il profilo usato per statistiche, team, matchmaking e allenamenti.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RallyColors.surfaceHigh, RallyColors.surface],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? RallyColors.lime.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? RallyColors.lime.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? RallyColors.lime : Colors.white60,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? RallyColors.lime : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: selected
                  ? RallyColors.lime.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? RallyColors.lime.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? RallyColors.lime : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
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

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.white54,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}
