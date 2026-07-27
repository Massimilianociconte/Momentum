/// Shared UI building blocks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entitlements.dart';
import 'brand.dart';
import 'mascot_3d.dart';
import 'navigation_targets.dart';
import 'paywall_nav.dart';
import 'providers.dart';
import 'theme.dart';

/// AppBar leading that always exits the current route, even after a deep link
/// replaced the stack (when [Navigator.canPop] is false).
class SafeBackButton extends StatelessWidget {
  const SafeBackButton({super.key, this.fallback = AppLocations.home, this.tooltip});

  final String fallback;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => AppNavigation.popOrGo(context, fallback: fallback),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Recoverable error surface for shell tabs and data screens.
class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Riprova',
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SectionCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.wifi_tethering_error_rounded,
                color: RallyColors.loss,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = this.secondaryLabel;
    final onSecondary = this.onSecondary;

    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: RallyColors.lime.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: RallyColors.lime, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPrimary,
            icon: Icon(primaryIcon ?? icon, size: 20),
            label: Text(primaryLabel),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onSecondary,
              icon: Icon(secondaryIcon ?? Icons.arrow_forward, size: 18),
              label: Text(secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}

/// Premium gate: shows child if entitled, else a lock teaser → paywall.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.gateKey,
    required this.entitled,
    required this.child,
  });

  final String gateKey;
  final bool Function(Entitlements) entitled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ents = ref.watch(entitlementsProvider);
    if (entitled(ents)) return child;
    final gate = gates[gateKey];
    return SectionCard(
      onTap: () => pushPaywall(
        context,
        gate: gateKey,
        plan: gate?.requiredPlan,
        reason: gate?.pitch,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: RallyColors.lime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock, color: RallyColors.lime, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sblocca con ${gate?.requiredPlan.label ?? 'Plus/Pro'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (gate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      gate.pitch,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white60,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}

/// Disclosure IA persistente sulle superfici conversazionali di Pallino.
///
/// Reg. UE 2024/1689 (AI Act) art. 50 §1 — applicabile dal 2 agosto 2026:
/// chi interagisce direttamente con un sistema di IA deve esserne informato,
/// "unless this is obvious". Una mascotte con un nome proprio non rende ovvia
/// la natura artificiale dell'interlocutore, quindi la disclosure resta
/// sempre visibile sopra la conversazione (non è un banner dismissibile).
class AssistantAiDisclosureBanner extends StatelessWidget {
  const AssistantAiDisclosureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: false,
      child: Container(
        width: double.infinity,
        color: RallyColors.surfaceHigh,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 15, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppBrand.assistantAiDisclosure,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pallino, la mascotte 3D (PRD E1): floating button che apre Rules/Assistant.
class MascotFab extends StatelessWidget {
  const MascotFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'mascot',
      tooltip: AppBrand.assistantName,
      backgroundColor: Colors.black,
      foregroundColor: RallyColors.lime,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () => context.push('/rules'),
      child: const Mascot3d(
        kind: Mascot3dKind.assistant,
        size: 48,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    );
  }
}

/// Risolve una signed URL una sola volta per objectPath e la conserva tra i
/// rebuild: senza memoizzazione ogni rebuild creerebbe un nuovo Future, con un
/// frame di fallback (flicker) e round-trip ripetuti al servizio immagini.
class SignedUrlImage extends StatefulWidget {
  const SignedUrlImage({
    super.key,
    required this.objectPath,
    required this.resolve,
    required this.builder,
  });

  final String? objectPath;
  final Future<String?> Function(String?) resolve;
  final Widget Function(String? url) builder;

  @override
  State<SignedUrlImage> createState() => _SignedUrlImageState();
}

class _SignedUrlImageState extends State<SignedUrlImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SignedUrlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectPath != widget.objectPath) {
      _url = null;
      _load();
    }
  }

  void _load() {
    final path = widget.objectPath;
    if (path == null || path.isEmpty) return;
    widget.resolve(path).then((url) {
      if (!mounted || widget.objectPath != path) return;
      if (url != null && url.isNotEmpty && url != _url) {
        setState(() => _url = url);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_url);
}

String formatDuration(int ms) {
  final m = (ms / 60000).round();
  if (m < 60) return "$m'";
  return "${m ~/ 60}h ${m % 60}'";
}

String formatDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  const months = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
