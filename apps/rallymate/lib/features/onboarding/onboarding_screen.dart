/// First-run onboarding + profile editor.
///
/// First run is an immersive tour followed by the essential local profile setup.
/// With [edit] = true the same route becomes a compact profile editor.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rally_core/rally_core.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.edit = false});

  final bool edit;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _tourSlides = [
    _TourSlide(
      image: 'assets/onboarding/onboarding_welcome.jpg',
      eyebrow: 'PADELANDIA',
      title: 'Il campo, i dati e il tuo progresso in un unico posto.',
      body:
          'Segna ogni punto, tieni traccia delle partite e costruisci una routine da giocatore più consapevole.',
      cta: 'Scopri come funziona',
    ),
    _TourSlide(
      image: 'assets/onboarding/onboarding_watch.jpg',
      eyebrow: 'SMARTWATCH',
      title: 'Segna i punti dal polso senza interrompere il gioco.',
      body:
          'Avvia una partita sul telefono, aggiorna il punteggio dal watch e ritrova tutto sincronizzato.',
      cta: 'Continua',
    ),
    _TourSlide(
      image: 'assets/onboarding/onboarding_social.jpg',
      eyebrow: 'SOCIAL E TEAM',
      title: 'Trova giocatori compatibili e crea team migliori.',
      body:
          'Livello, disponibilità, stile di gioco e statistiche aiutano a organizzare partite più equilibrate.',
      cta: 'Continua',
    ),
    _TourSlide(
      image: 'assets/onboarding/onboarding_training.jpg',
      eyebrow: 'TRAINING',
      title: 'Trasforma i dati partita in allenamenti mirati.',
      body:
          'Padelandia suggerisce esercizi, obiettivi settimanali e routine coerenti con il tuo ruolo in campo.',
      cta: 'Continua',
    ),
    _TourSlide(
      image: 'assets/onboarding/onboarding_premium.jpg',
      eyebrow: 'PLUS E PRO',
      title: 'Sblocca assistente Pro, backup e insight avanzati.',
      body:
          'Plus aggiunge backup e team illimitati; Pro sblocca Pallino AI, analisi evolute e integrazioni fitness.',
      cta: 'Configura profilo',
    ),
  ];

  final _pageController = PageController();
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _goal = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _accountFormKey = GlobalKey<FormState>();
  DominantHand _hand = DominantHand.rightHand;
  PadelRole _role = PadelRole.undefined;
  PlayerLevel _level = PlayerLevel.intermediate;
  int _page = 0;
  int _editStep = 0;
  bool _imagesPrecached = false;
  bool _accountBusy = false;
  bool _accountObscure = true;
  bool _accountCreated = false;
  String? _accountError;
  String? _accountInfo;

  int get _totalPages => _tourSlides.length + 4;
  bool get _isLastPage => _page == _totalPages - 1;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _nickname.dispose();
    _goal.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final me = await ref.read(playerRepoProvider).me();
    if (me == null || !mounted) return;
    setState(() {
      _name.text = me.name == 'Giocatore' ? '' : me.name;
      _nickname.text = me.nickname;
      _goal.text = me.goal;
      _hand = DominantHand.fromWire(me.dominantHand);
      _role = PadelRole.fromWire(me.preferredRole);
      _level = PlayerLevel.fromWire(me.level);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    for (final slide in _tourSlides) {
      unawaited(precacheImage(AssetImage(slide.image), context));
    }
    unawaited(
      precacheImage(
        const AssetImage('assets/onboarding/onboarding_welcome.jpg'),
        context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.edit) return _buildEditor(context);
    return _buildFirstRun(context);
  }

  Widget _buildFirstRun(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _page = page),
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              if (index < _tourSlides.length) {
                return _TourPage(slide: _tourSlides[index]);
              }
              final setupIndex = index - _tourSlides.length;
              if (setupIndex < 3) {
                return _ProfileSetupPage(
                  index: setupIndex,
                  name: _name,
                  nickname: _nickname,
                  goal: _goal,
                  hand: _hand,
                  role: _role,
                  level: _level,
                  onHandChanged: (v) => setState(() => _hand = v),
                  onRoleChanged: (v) => setState(() => _role = v),
                  onLevelChanged: (v) => setState(() => _level = v),
                );
              }
              return _AccountSetupPage(
                formKey: _accountFormKey,
                email: _email,
                password: _password,
                obscurePassword: _accountObscure,
                configured: CloudConfig.supabaseConfigured,
                busy: _accountBusy,
                accountCreated: _accountCreated,
                error: _accountError,
                info: _accountInfo,
                onTogglePassword: () =>
                    setState(() => _accountObscure = !_accountObscure),
                onSignIn: _openSignIn,
              );
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: _OnboardingControls(
                page: _page,
                totalPages: _totalPages,
                primaryLabel: _primaryLabel,
                secondaryLabel: _secondaryLabel,
                onPrimary: _next,
                onSecondary: _secondaryAction,
                busy: _accountBusy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _primaryLabel {
    if (_isLastPage) {
      if (!CloudConfig.supabaseConfigured) return 'Entra in campo';
      // Account is optional: primary always finishes onboarding and lands home.
      return _accountCreated ? 'Entra in campo' : 'Entra in campo';
    }
    if (_page < _tourSlides.length) return _tourSlides[_page].cta;
    return 'Avanti';
  }

  String? get _secondaryLabel {
    // Tour: always allow skipping intro to essential profile setup.
    if (_page < _tourSlides.length) {
      if (_page == 4) return 'Vedi Plus/Pro';
      return 'Salta intro';
    }
    if (_isLastPage && CloudConfig.supabaseConfigured && !_accountCreated) {
      return 'Crea account gratuito';
    }
    return null;
  }

  VoidCallback? get _secondaryAction {
    if (_page < _tourSlides.length) {
      if (_page == 4) return () => context.push('/paywall');
      return _skipTour;
    }
    if (_isLastPage && CloudConfig.supabaseConfigured && !_accountCreated) {
      return _createAccount;
    }
    return null;
  }

  Future<void> _skipTour() async {
    await _pageController.animateToPage(
      _tourSlides.length,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildEditor(BuildContext context) {
    final bottomPadding = 24 + MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: RallyColors.night,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Modifica profilo')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RallyColors.night, Color(0xFF0B121E)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
            children: [
              const Text(
                'Aggiorna il profilo usato da team, training e social.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _StepPill(currentStep: _editStep, totalSteps: 3),
              const SizedBox(height: 18),
              _buildProfileStep(_editStep),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_editStep > 0)
                    TextButton.icon(
                      onPressed: () => setState(() => _editStep--),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Indietro'),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/profile');
                        }
                      },
                      child: const Text('Annulla'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _editStep == 2
                        ? _saveProfile
                        : () => setState(() => _editStep++),
                    icon: Icon(
                      _editStep == 2
                          ? Icons.check_rounded
                          : Icons.chevron_right,
                    ),
                    label: Text(_editStep == 2 ? 'Salva profilo' : 'Avanti'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep(int step) {
    return _ProfileSetupPage(
      index: step,
      embedded: true,
      name: _name,
      nickname: _nickname,
      goal: _goal,
      hand: _hand,
      role: _role,
      level: _level,
      onHandChanged: (v) => setState(() => _hand = v),
      onRoleChanged: (v) => setState(() => _role = v),
      onLevelChanged: (v) => setState(() => _level = v),
    );
  }

  Future<void> _next() async {
    if (_isLastPage) {
      // Primary path: finish and play. Account is secondary CTA only.
      await _saveProfile();
      return;
    }
    if (_page == _tourSlides.length && _name.text.trim().isEmpty) {
      _name.text = 'Giocatore';
    }
    await _pageController.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveProfile() async {
    await _persistProfile();
    await _completeOnboarding(syncProfile: true);
  }

  Future<void> _persistProfile() async {
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
        );
  }

  Future<void> _completeOnboarding({required bool syncProfile}) async {
    await ref.read(keyValueRepoProvider).set('onboarding_done', 'true');
    ref.read(onboardingDoneProvider.notifier).state = true;
    ref.invalidate(meProvider);
    if (syncProfile) {
      unawaited(ref.read(cloudAuthProvider.notifier).maybeSyncBasicProfile());
    }
    final pending =
        await ref.read(cloudAuthProvider.notifier).takePendingDeepLink();
    if (!mounted) return;
    if (widget.edit) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
      return;
    }
    // First-run success path: land on match setup when no deep link pending.
    if (pending != null) {
      context.go(pending);
      return;
    }
    if (!widget.edit) {
      context.go('/match/new');
      return;
    }
    context.go('/home');
  }

  Future<void> _createAccount() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _accountBusy = true;
      _accountError = null;
      _accountInfo = null;
    });

    await _persistProfile();
    final result = await ref
        .read(cloudAuthProvider.notifier)
        .signUp(_email.text.trim(), _password.text);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _accountBusy = false;
        _accountError = result.message;
      });
      return;
    }

    if (result.emailConfirmationRequired) {
      setState(() {
        _accountBusy = false;
        _accountCreated = true;
        _accountInfo = result.message;
      });
      return;
    }

    setState(() => _accountBusy = false);
    await _completeOnboarding(syncProfile: false);
  }

  Future<void> _openSignIn() async {
    if (_accountBusy) return;
    await _persistProfile();
    ref.invalidate(meProvider);
    if (!mounted) return;
    // Do NOT mark onboarding_done until login succeeds; cancel returns here.
    context.go(
      '/auth?returnTo=${Uri.encodeQueryComponent('/onboarding')}',
    );
  }
}

class _TourSlide {
  const _TourSlide({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.cta,
  });

  final String image;
  final String eyebrow;
  final String title;
  final String body;
  final String cta;
}

class _TourPage extends StatelessWidget {
  const _TourPage({required this.slide});

  final _TourSlide slide;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.image,
            fit: BoxFit.cover,
            cacheWidth: _screenCacheWidth(context),
            filterQuality: FilterQuality.low,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xDD070B16),
                  Color(0x33070B16),
                  Color(0xF2070B16),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: RallyColors.lime.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      slide.eyebrow,
                      style: const TextStyle(
                        color: RallyColors.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    slide.title,
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      height: 1.03,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    slide.body,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _screenCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .ceil()
      .clamp(720, 1200)
      .toInt();
}

class _ProfileSetupPage extends StatelessWidget {
  const _ProfileSetupPage({
    required this.index,
    required this.name,
    required this.nickname,
    required this.goal,
    required this.hand,
    required this.role,
    required this.level,
    required this.onHandChanged,
    required this.onRoleChanged,
    required this.onLevelChanged,
    this.embedded = false,
  });

  final int index;
  final bool embedded;
  final TextEditingController name;
  final TextEditingController nickname;
  final TextEditingController goal;
  final DominantHand hand;
  final PadelRole role;
  final PlayerLevel level;
  final ValueChanged<DominantHand> onHandChanged;
  final ValueChanged<PadelRole> onRoleChanged;
  final ValueChanged<PlayerLevel> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final content = _ProfileCard(child: _stepContent(context));
    if (embedded) return content;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/onboarding/onboarding_welcome.jpg',
          fit: BoxFit.cover,
          cacheWidth: _screenCacheWidth(context),
          filterQuality: FilterQuality.low,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xEE070B16), Color(0xCC070B16), Color(0xFF070B16)],
            ),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
            children: [
              _StepPill(currentStep: index, totalSteps: 3),
              const SizedBox(height: 18),
              content,
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context) {
    switch (index) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProfileStepTitle(
              title: 'Partiamo da te',
              subtitle:
                  'Nome e nickname servono solo per personalizzare app, team e condivisioni.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nickname,
              decoration: const InputDecoration(
                labelText: 'Nickname (opzionale)',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProfileStepTitle(
              title: 'Come giochi?',
              subtitle:
                  'Ruolo e mano dominante rendono piu utili training e analisi.',
            ),
            const SizedBox(height: 18),
            const _MiniLabel('MANO DOMINANTE'),
            const SizedBox(height: 8),
            SegmentedButton<DominantHand>(
              segments: const [
                ButtonSegment(
                  value: DominantHand.rightHand,
                  label: Text('Destra'),
                  icon: Icon(Icons.pan_tool_alt_outlined),
                ),
                ButtonSegment(
                  value: DominantHand.leftHand,
                  label: Text('Sinistra'),
                  icon: Icon(Icons.back_hand_outlined),
                ),
              ],
              selected: {hand},
              onSelectionChanged: (s) => onHandChanged(s.first),
            ),
            const SizedBox(height: 20),
            const _MiniLabel('RUOLO PREFERITO'),
            const SizedBox(height: 8),
            _roleTile(PadelRole.left, 'Sinistra', 'Chiusura, bandeja, smash'),
            _roleTile(PadelRole.right, 'Destra', 'Regia, difesa, continuita'),
            _roleTile(PadelRole.flex, 'Flex', 'Ti adatti a partner e partita'),
            _roleTile(
              PadelRole.undefined,
              'Non lo so ancora',
              'Lo capirai con le prime statistiche',
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProfileStepTitle(
              title: 'Obiettivo e livello',
              subtitle:
                  'Bastano pochi dati: il resto lo costruiremo con le partite.',
            ),
            const SizedBox(height: 16),
            for (final l in PlayerLevel.values) _levelTile(l),
            const SizedBox(height: 12),
            TextField(
              controller: goal,
              decoration: const InputDecoration(
                labelText: 'Obiettivo (opzionale)',
                prefixIcon: Icon(Icons.track_changes),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        );
    }
  }

  Widget _roleTile(PadelRole value, String title, String subtitle) {
    final selected = role == value;
    return _SelectableTile(
      selected: selected,
      title: title,
      subtitle: subtitle,
      onTap: () => onRoleChanged(value),
    );
  }

  Widget _levelTile(PlayerLevel value) {
    final selected = level == value;
    return _SelectableTile(
      selected: selected,
      title: _levelLabel(value),
      subtitle: _levelSubtitle(value),
      onTap: () => onLevelChanged(value),
    );
  }

  String _levelLabel(PlayerLevel l) => switch (l) {
    PlayerLevel.beginner => 'Principiante',
    PlayerLevel.improver => 'In crescita',
    PlayerLevel.intermediate => 'Intermedio',
    PlayerLevel.advanced => 'Avanzato',
    PlayerLevel.competition => 'Agonista',
  };

  String _levelSubtitle(PlayerLevel l) => switch (l) {
    PlayerLevel.beginner => 'Stai costruendo le basi',
    PlayerLevel.improver => 'Giochi gia, vuoi continuita',
    PlayerLevel.intermediate => 'Partite regolari e obiettivi chiari',
    PlayerLevel.advanced => 'Cerchi precisione e vantaggio tattico',
    PlayerLevel.competition => 'Allenamento e match competitivi',
  };
}

class _AccountSetupPage extends StatelessWidget {
  const _AccountSetupPage({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscurePassword,
    required this.configured,
    required this.busy,
    required this.accountCreated,
    required this.onTogglePassword,
    required this.onSignIn,
    this.error,
    this.info,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscurePassword;
  final bool configured;
  final bool busy;
  final bool accountCreated;
  final String? error;
  final String? info;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/onboarding/onboarding_welcome.jpg',
          fit: BoxFit.cover,
          cacheWidth: _screenCacheWidth(context),
          filterQuality: FilterQuality.low,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xEE070B16), Color(0xCC070B16), Color(0xFF070B16)],
            ),
          ),
        ),
        SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 170),
            children: [
              const _StepPill(currentStep: 3, totalSteps: 4),
              const SizedBox(height: 18),
              _ProfileCard(
                child: accountCreated
                    ? _buildConfirmation()
                    : configured
                    ? _buildForm()
                    : _buildUnavailable(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProfileStepTitle(
              title: 'Proteggi il tuo profilo',
              subtitle:
                  'Crea un account gratuito con email. Padelandia resta '
                  'utilizzabile anche senza login; il backup completo di '
                  'partite e allenamenti rimane una funzione Premium.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: email,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              validator: (value) =>
                  RegExp(r'^\S+@\S+\.\S+$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Inserisci una email valida',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Almeno 8 caratteri',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: obscurePassword
                      ? 'Mostra password'
                      : 'Nascondi password',
                  onPressed: busy ? null : onTogglePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) =>
                  (value ?? '').length >= 8 ? null : 'Minimo 8 caratteri',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _AccountMessage(message: error!, error: true),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  color: RallyColors.cyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'L’email serve per accesso, verifica e recupero account. '
                    'Non viene mostrata agli altri giocatori.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: busy ? null : onSignIn,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Hai già un account? Accedi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: RallyColors.lime,
          size: 36,
        ),
        const SizedBox(height: 14),
        const _ProfileStepTitle(
          title: 'Controlla la tua email',
          subtitle:
              'Il profilo locale è pronto. Apri il link ricevuto per '
              'confermare l’account, poi potrai accedere da qualsiasi dispositivo.',
        ),
        if (info != null) ...[
          const SizedBox(height: 14),
          _AccountMessage(message: info!, error: false),
        ],
      ],
    );
  }

  Widget _buildUnavailable() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.cloud_off_outlined, color: Colors.white54, size: 34),
        SizedBox(height: 14),
        _ProfileStepTitle(
          title: 'Profilo locale pronto',
          subtitle:
              'Questa build non ha ancora il servizio account configurato. '
              'Puoi continuare offline senza perdere le funzioni locali e '
              'creare l’account più tardi dal Profilo.',
        ),
      ],
    );
  }
}

class _AccountMessage extends StatelessWidget {
  const _AccountMessage({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? RallyColors.loss : RallyColors.win;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          message,
          style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF152030), Color(0xFF0B121E)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileStepTitle extends StatelessWidget {
  const _ProfileStepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, height: 1.35),
        ),
      ],
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
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

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.page,
    required this.totalPages,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  final int page;
  final int totalPages;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE08101B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < totalPages; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: i == page ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == page ? RallyColors.lime : Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (secondaryLabel != null && onSecondary != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : onPrimary,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 5,
              decoration: BoxDecoration(
                color: i <= currentStep ? RallyColors.lime : Colors.white12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (i < totalSteps - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
