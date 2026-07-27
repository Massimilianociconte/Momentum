library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../services/cloud/invite_service.dart';

Future<void> showInviteShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  String? teamId,
  String? matchId,
  String? duoSessionId,
  String? targetUserId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: RallyColors.surface,
  builder: (_) => _InviteShareContent(
    kind: kind,
    teamId: teamId,
    matchId: matchId,
    duoSessionId: duoSessionId,
    targetUserId: targetUserId,
  ),
);

class _InviteShareContent extends ConsumerStatefulWidget {
  const _InviteShareContent({
    required this.kind,
    this.teamId,
    this.matchId,
    this.duoSessionId,
    this.targetUserId,
  });

  final String kind;
  final String? teamId;
  final String? matchId;
  final String? duoSessionId;
  final String? targetUserId;

  @override
  ConsumerState<_InviteShareContent> createState() =>
      _InviteShareContentState();
}

class _InviteShareContentState extends ConsumerState<_InviteShareContent> {
  CreatedInvite? _invite;
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() {
      _invite = null;
      _error = null;
    });
    final result = await ref
        .read(inviteServiceProvider)
        .create(
          kind: widget.kind,
          teamId: widget.teamId,
          matchId: widget.matchId,
          duoSessionId: widget.duoSessionId,
          targetUserId: widget.targetUserId,
        );
    if (!mounted) return;
    setState(() {
      _invite = result.invite;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title(widget.kind),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Chi riceve vede il tuo nome e conferma prima del collegamento.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Icon(Icons.error_outline, color: RallyColors.loss, size: 42),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ] else if (invite == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              )
            else ...[
              Semantics(
                image: true,
                label: 'Codice QR invito Momentum',
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: invite.uri.toString(),
                    version: QrVersions.auto,
                    size: 210,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: RallyColors.night,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: RallyColors.night,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CODICE INVITO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                invite.code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: RallyColors.lime,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Scade ${DateFormat('dd/MM alle HH:mm').format(invite.expiresAt.toLocal())}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          ref.read(inviteServiceProvider).share(invite),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Condividi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: invite.uri.toString()),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiato.')),
                      );
                    },
                    icon: const Icon(Icons.link),
                    tooltip: 'Copia link',
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: invite.code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Codice copiato.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copia codice',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _revoke(invite),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Revoca questo invito'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _title(String kind) => switch (kind) {
    'PROFILE' => 'Condividi profilo giocatore',
    'TEAM_JOIN' => 'Invita nel team',
    'DUO' => 'Invita in Duo Mode',
    'MATCH' => 'Invita alla partita',
    _ => 'Il mio invito amico',
  };

  Future<void> _revoke(CreatedInvite invite) async {
    final error = await ref.read(inviteServiceProvider).revoke(invite.id);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invito revocato.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
