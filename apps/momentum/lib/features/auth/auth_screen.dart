/// Account gratuito (PRD 5.1): login / registrazione / recupero password e
/// gestione account. Il piano Free sincronizza SOLO il profilo base
/// (nome, nickname, mano, ruolo, livello, privacy): il backup completo
/// resta una funzione Plus separata.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation_targets.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/cloud/cloud_config.dart';
import '../../services/cloud/cloud_service.dart';

/// Ultima sync del profilo base (scritta da CloudAuth.syncBasicProfile).
final _lastBasicSyncProvider = StreamProvider<String?>(
  (ref) => ref.watch(keyValueRepoProvider).watch('last_basic_profile_sync'),
);

enum _AuthMode { signIn, signUp, reset }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startMode = 'signin', this.returnTo});

  /// 'signin' | 'signup' (da query param /auth?mode=...).
  final String startMode;
  final String? returnTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late _AuthMode _mode = widget.startMode == 'signup'
      ? _AuthMode.signUp
      : _AuthMode.signIn;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;
  bool _awaitingEmailConfirmation = false;

  bool _oauthReturnHandled = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(cloudAuthProvider);
    if (auth.profileLinkStatus == ProfileLinkStatus.pendingEmailVerification &&
        auth.email?.isNotEmpty == true &&
        _email.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _email.text.isNotEmpty) return;
        setState(() {
          _email.text = auth.email!;
          _awaitingEmailConfirmation = true;
          _info = 'Conferma l’indirizzo dal messaggio ricevuto via email.';
        });
      });
    }

    // After Google OAuth / email confirmation deep link, resume returnTo once
    // the profile is linked (or only signed in when no link is required).
    if (!_oauthReturnHandled &&
        auth.signedIn &&
        auth.profileLinked &&
        !auth.passwordRecovery) {
      _oauthReturnHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_finishAuthFlow());
      });
    }

    final fallback = (widget.returnTo != null &&
            widget.returnTo!.startsWith('/') &&
            !widget.returnTo!.startsWith('/auth') &&
            !widget.returnTo!.startsWith('//'))
        ? widget.returnTo!
        : AppLocations.profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(auth.signedIn ? 'Il tuo account' : 'Account Momentum'),
        leading: SafeBackButton(fallback: fallback),
      ),
      body: !CloudConfig.supabaseConfigured
          ? _CloudUnavailable(validation: CloudConfig.validation)
          : auth.passwordRecovery
          ? _PasswordRecoveryView(returnTo: widget.returnTo)
          : auth.signedIn
          ? _SignedInView(
              auth: auth,
              email: auth.email,
              emailConfirmed: auth.emailConfirmed,
              returnTo: widget.returnTo,
            )
          : _buildForm(context),
    );
  }

  // ------------------------------------------------------------ form

  Widget _buildForm(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final hasLocalData =
        me != null &&
        ((me.name.trim().isNotEmpty && me.name != 'Giocatore') ||
            me.nickname.trim().isNotEmpty);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/mascot/rally_mascot_encourage.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  switch (_mode) {
                    _AuthMode.signIn => 'Bentornato in campo',
                    _AuthMode.signUp => 'Crea il tuo account gratuito',
                    _AuthMode.reset => 'Recupera la password',
                  },
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            switch (_mode) {
              _AuthMode.reset =>
                'Ti inviamo una email con il link per impostare una nuova '
                    'password.',
              _ =>
                'L’account gratuito salva nel cloud solo il profilo base: '
                    'nome, nickname, mano, ruolo, livello e privacy. Partite e '
                    'statistiche restano sul dispositivo (backup completo: Plus).',
            },
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (hasLocalData) ...[
            _LocalProfileContinuityBanner(name: me.name),
            const SizedBox(height: 16),
          ],
          if (_mode != _AuthMode.reset) ...[
            SegmentedButton<_AuthMode>(
              segments: const [
                ButtonSegment(
                  value: _AuthMode.signIn,
                  label: Text('Accedi'),
                  icon: Icon(Icons.login),
                ),
                ButtonSegment(
                  value: _AuthMode.signUp,
                  label: Text('Registrati'),
                  icon: Icon(Icons.person_add_alt_1),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                      _info = null;
                      _awaitingEmailConfirmation = false;
                    }),
            ),
            const SizedBox(height: 18),
          ],
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _mode == _AuthMode.reset
                      ? TextInputAction.done
                      : TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  validator: _validateEmail,
                  onFieldSubmitted: (_) {
                    if (_mode == _AuthMode.reset) _submit();
                  },
                ),
                if (_mode != _AuthMode.reset) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      helperText: _mode == _AuthMode.signUp
                          ? 'Almeno 8 caratteri'
                          : null,
                    ),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: _mode == _AuthMode.signUp
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ],
            ),
          ),
          if (_mode == _AuthMode.signIn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _mode = _AuthMode.reset;
                        _error = null;
                        _info = null;
                      }),
                child: const Text('Password dimenticata?'),
              ),
            ),
          if (_error != null) _MessageBanner(message: _error!, error: true),
          if (_info != null) _MessageBanner(message: _info!, error: false),
          if (_awaitingEmailConfirmation)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _resendConfirmation,
                icon: const Icon(Icons.forward_to_inbox, size: 18),
                label: const Text('Rinvia email di conferma'),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(switch (_mode) {
                    _AuthMode.signIn => Icons.login,
                    _AuthMode.signUp => Icons.person_add_alt_1,
                    _AuthMode.reset => Icons.send,
                  }),
            label: Text(switch (_mode) {
              _AuthMode.signIn => 'Accedi',
              _AuthMode.signUp => 'Crea account',
              _AuthMode.reset => 'Invia email di recupero',
            }),
          ),
          if (_mode != _AuthMode.reset) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _googleSignIn,
              icon: const Icon(Icons.g_mobiledata, size: 26),
              label: const Text('Continua con Google'),
            ),
          ],
          if (_mode == _AuthMode.reset)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _mode = _AuthMode.signIn;
                      _error = null;
                      _info = null;
                    }),
              child: const Text('Torna al login'),
            ),
        ],
      ),
    );
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    // Volutamente permissiva: il controllo vero lo fa il server.
    final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);
    return ok ? null : 'Inserisci una email valida';
  }

  String? _validatePassword(String? v) {
    if (_mode == _AuthMode.reset) return null;
    if ((v ?? '').length < 8) return 'Minimo 8 caratteri';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final authService = ref.read(cloudAuthProvider.notifier);
    // Persist returnTo for email confirmation / recovery deep links.
    await authService.stashAuthReturnTo(widget.returnTo);
    final email = _email.text.trim();
    final result = switch (_mode) {
      _AuthMode.signIn => await authService.signIn(email, _password.text),
      _AuthMode.signUp => await authService.signUp(email, _password.text),
      _AuthMode.reset => await authService.resetPassword(email),
    };

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _error = null;
        _info = result.message;
        _awaitingEmailConfirmation = result.emailConfirmationRequired;
      } else {
        _error = result.message;
      }
    });

    // Login/registrazione riusciti con sessione attiva: torna da dove si era.
    final auth = ref.read(cloudAuthProvider);
    if (result.ok && auth.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Accesso effettuato, profilo sincronizzato ✅',
          ),
        ),
      );
      if (!result.profileLinkRequired && auth.profileLinked) {
        _oauthReturnHandled = true;
        unawaited(_finishAuthFlow());
      }
    }
  }

  Future<void> _googleSignIn() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final authNotifier = ref.read(cloudAuthProvider.notifier);
    await authNotifier.stashAuthReturnTo(widget.returnTo);
    final result = await authNotifier.signInWithGoogle(
      returnTo: widget.returnTo,
    );
    if (!mounted) return;
    // Al ritorno dal browser la sessione arriva via deep link: build() watcha
    // cloudAuthProvider e passa da solo alla vista account.
    setState(() {
      _busy = false;
      if (result.ok) {
        _info = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _resendConfirmation() async {
    setState(() => _busy = true);
    final result = await ref
        .read(cloudAuthProvider.notifier)
        .resendConfirmation(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _info = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _finishAuthFlow() async {
    if (!mounted) return;
    var destination = widget.returnTo;
    destination ??= await ref.read(cloudAuthProvider.notifier).takeAuthReturnTo();
    if (!mounted) return;
    if (destination == '/onboarding') {
      // Login started from the first-run tour: now mark onboarding complete.
      await ref.read(keyValueRepoProvider).set('onboarding_done', 'true');
      ref.read(onboardingDoneProvider.notifier).state = true;
      destination = AppLocations.home;
    }
    if (destination != null &&
        destination.startsWith('/') &&
        !destination.startsWith('/auth') &&
        !destination.startsWith('//')) {
      final pending = await ref
          .read(cloudAuthProvider.notifier)
          .takePendingDeepLink();
      if (!mounted) return;
      final target = pending ?? destination;
      // Prefer pop when auth was pushed (paywall/devices) so origin stack lives.
      if (context.canPop() &&
          (target == '/paywall' ||
              target.startsWith('/devices') ||
              target == '/profile' ||
              target.startsWith('/profile?'))) {
        context.pop();
        return;
      }
      context.go(target);
      return;
    }
    final pending = await ref
        .read(cloudAuthProvider.notifier)
        .takePendingDeepLink();
    if (!mounted) return;
    if (pending != null) {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(pending);
      return;
    }
    AppNavigation.popOrGo(context, fallback: AppLocations.profile);
  }
}

class _PasswordRecoveryView extends ConsumerStatefulWidget {
  const _PasswordRecoveryView({this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<_PasswordRecoveryView> createState() =>
      _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends ConsumerState<_PasswordRecoveryView> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Icon(Icons.lock_reset, size: 54, color: RallyColors.lime),
          const SizedBox(height: 14),
          const Text(
            'Scegli una nuova password',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Il link è stato verificato. Inserisci una password di almeno '
            '8 caratteri per completare il recupero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Nuova password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (value) => (value ?? '').length < 8
                      ? 'Usa almeno 8 caratteri'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Conferma password',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  validator: (value) => value != _password.text
                      ? 'Le password non coincidono'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          if (_error != null) _MessageBanner(message: _error!, error: true),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Aggiorna password'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(cloudAuthProvider.notifier)
        .updateRecoveredPassword(_password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.ok ? null : result.message;
    });
    if (!result.ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Password aggiornata.')),
    );
    final destination = widget.returnTo;
    if (destination != null && destination.startsWith('/')) {
      context.go(destination);
    } else {
      context.go('/auth');
    }
  }
}

// ---------------------------------------------------------------- signed-in

class _SignedInView extends ConsumerStatefulWidget {
  const _SignedInView({
    required this.auth,
    required this.email,
    required this.emailConfirmed,
    this.returnTo,
  });
  final AuthState auth;
  final String? email;
  final bool emailConfirmed;
  final String? returnTo;

  @override
  ConsumerState<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends ConsumerState<_SignedInView> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ents = ref.watch(entitlementsProvider);
    final lastSync = ref.watch(_lastBasicSyncProvider).value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (!widget.auth.profileLinked) ...[
          _ProfileLinkCard(
            status: widget.auth.profileLinkStatus,
            busy: _busy,
            onLink: _linkLocalProfile,
            onContinueLocal: _continueLocally,
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          title: 'ACCOUNT',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user,
                    color: RallyColors.win,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.email ?? 'Account attivo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Piano ${ents.plan.label} · '
                          '${widget.emailConfirmed ? 'email verificata' : 'verifica email in attesa'} · '
                          '${widget.auth.profileLinked ? 'profilo collegato' : 'collegamento richiesto'}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lastSync == null
                    ? 'Profilo base non ancora sincronizzato.'
                    : 'Ultima sync profilo: ${_formatSync(lastSync)}',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _changeEmail,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Cambia email'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'SYNC PROFILO BASE (GRATIS)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nome, nickname, mano, ruolo, livello e privacy seguono il tuo '
                'account su qualsiasi dispositivo. Partite, statistiche e '
                'allenamenti restano locali.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy || !widget.auth.profileLinked
                    ? null
                    : _syncNow,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sincronizza ora'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'BACKUP COMPLETO (PLUS)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Salva profilo completo, partner, team, immagini cloud, '
                'partite con timeline punti, progressi training e preferenze '
                'trasferibili. Analytics e statistiche vengono ricostruiti '
                'dai dati originali. Dati salute, token e dispositivi sono esclusi.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              if (!widget.auth.profileLinked)
                const Text(
                  'Collega prima il profilo locale a questo account.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white54),
                )
              else if (!ents.cloudBackup)
                OutlinedButton.icon(
                  onPressed: () => context.push('/paywall'),
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: const Text('Sblocca con Plus'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => ref
                                    .read(backupServiceProvider)
                                    .backupNow(),
                              ),
                        icon: const Icon(Icons.cloud_upload, size: 18),
                        label: const Text('Backup ora'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _confirmRestore,
                        icon: const Icon(Icons.cloud_download, size: 18),
                        label: const Text('Ripristina'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _confirmDeleteBackup,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Elimina il backup cloud'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'SESSIONE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uscendo, i dati locali restano sul dispositivo. Il piano '
                'premium segue l’account, non il telefono.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: RallyColors.loss,
                ),
                onPressed: _busy ? null : _confirmSignOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Esci dall’account'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: RallyColors.loss),
                onPressed: _busy ? null : _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Elimina account e dati cloud'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _linkLocalProfile() async {
    if (widget.auth.profileLinkStatus == ProfileLinkStatus.differentAccount) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Collegare a questo account?'),
          content: const Text(
            'Questo dispositivo era associato a un altro account. I dati '
            'locali non verranno eliminati, ma da ora saranno collegati '
            'all’account attualmente aperto. Nessuna modifica viene fatta '
            'senza questa conferma.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Collega account'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(cloudAuthProvider.notifier)
        .linkLocalProfile();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Profilo collegato.')),
    );
    if (!result.ok) return;
    final destination = widget.returnTo;
    if (destination != null &&
        destination.startsWith('/') &&
        !destination.startsWith('/auth')) {
      context.go(destination);
    }
  }

  Future<void> _continueLocally() async {
    setState(() => _busy = true);
    await ref.read(cloudAuthProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: widget.email ?? '');
    final formKey = GlobalKey<FormState>();
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambia email'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Nuova email',
              prefixIcon: Icon(Icons.alternate_email),
              helperText: 'Il cambio deve essere confermato via email.',
            ),
            validator: (value) =>
                RegExp(r'^\S+@\S+\.\S+$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Inserisci una email valida',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Invia conferma'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(cloudAuthProvider.notifier).updateEmail(next);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Richiesta inviata.')),
    );
  }

  /// Doppia conferma (dialog + digitazione ELIMINA): requisito store,
  /// operazione irreversibile.
  Future<void> _confirmDeleteAccount() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare l’account?'),
        content: const Text(
          'Verranno eliminati DEFINITIVAMENTE: account, profilo cloud, '
          'backup, richieste social e card pubblicate. Le partite salvate '
          'su questo dispositivo restano tue.\n\n'
          'Gli abbonamenti attivi vanno disdetti da App Store / Google Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RallyColors.loss),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continua'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma definitiva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scrivi ELIMINA per confermare. Non è annullabile.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'ELIMINA'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RallyColors.loss),
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().toUpperCase() == 'ELIMINA',
            ),
            child: const Text('Elimina per sempre'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final error = await ref.read(cloudAuthProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Account eliminato. Grazie di aver giocato 🎾'),
      ),
    );
  }

  String _formatSync(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'adesso';
    if (diff.inHours < 1) return '${diff.inMinutes} min fa';
    if (diff.inDays < 1) return '${diff.inHours} h fa';
    return '${t.day}/${t.month}/${t.year}';
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    final error = await ref.read(cloudAuthProvider.notifier).syncBasicProfile();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Profilo base sincronizzato ✅')),
    );
  }

  Future<void> _run(Future<String?> Function() op) async {
    setState(() => _busy = true);
    final error = await op();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Operazione completata ✅')));
  }

  Future<void> _confirmRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristinare il backup?'),
        content: const Text(
          'Profilo, team, partite, timeline punti e allenamenti del backup '
          'verranno uniti ai dati presenti. Le statistiche saranno '
          'ricalcolate; dati salute e impostazioni del dispositivo non '
          'vengono importati. L’operazione non è annullabile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(() => ref.read(backupServiceProvider).restore());
    }
  }

  Future<void> _confirmDeleteBackup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il backup cloud?'),
        content: const Text(
          'Verrà eliminato il backup completo associato a questo account. '
          'I dati presenti sul dispositivo e il profilo base non cambiano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RallyColors.loss),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina backup'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(() async {
        final id = await ref
            .read(backupServiceProvider)
            .resolveBackupDeviceId();
        return ref.read(backupServiceProvider).deleteBackup(id);
      });
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dall’account?'),
        content: const Text(
          'Le partite e il profilo restano su questo dispositivo. '
          'La sync del profilo base e le funzioni cloud si disattivano '
          'finché non accedi di nuovo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RallyColors.loss),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await ref.read(cloudAuthProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sei uscito dall’account')));
  }
}

// ------------------------------------------------------------------ shared

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.error});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? RallyColors.loss : RallyColors.win;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudUnavailable extends StatelessWidget {
  const _CloudUnavailable({required this.validation});

  final CloudConfigValidation validation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: SectionCard(
        title: 'SERVIZI ONLINE NON DISPONIBILI',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Questa versione può essere usata in locale, ma account, social, '
              'backup e Pallino Assistant non sono disponibili. Installa una '
              'build Momentum configurata oppure riprova più tardi.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                'Diagnostica: ${validation.message}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/dev/cloud-diagnostics'),
                icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                label: const Text('Apri diagnostica'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalProfileContinuityBanner extends StatelessWidget {
  const _LocalProfileContinuityBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RallyColors.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RallyColors.cyan.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phonelink_lock, color: RallyColors.cyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Abbiamo trovato i dati locali di $name. Accedi o crea un '
              'account per collegarli senza perdere partite, team e preferenze. '
              'Puoi anche continuare a usare tutto solo su questo dispositivo.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLinkCard extends StatelessWidget {
  const _ProfileLinkCard({
    required this.status,
    required this.busy,
    required this.onLink,
    required this.onContinueLocal,
  });

  final ProfileLinkStatus status;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onContinueLocal;

  @override
  Widget build(BuildContext context) {
    final conflict = status == ProfileLinkStatus.differentAccount;
    return SectionCard(
      title: conflict ? 'CONFERMA ACCOUNT' : 'COLLEGA I DATI LOCALI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict
                ? 'Questo dispositivo risulta associato a un account diverso. '
                      'Scegli esplicitamente se collegare qui i dati locali.'
                : 'Hai già dati salvati su questo dispositivo. Collegali per '
                      'usare backup, social, Duo Mode e Pallino Assistant '
                      'senza perderli.',
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onLink,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('Collega senza perdere dati'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: busy ? null : onContinueLocal,
              child: const Text('Continua solo in locale'),
            ),
          ),
        ],
      ),
    );
  }
}
