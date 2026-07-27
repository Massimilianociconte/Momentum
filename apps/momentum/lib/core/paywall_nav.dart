/// Store-compliant paywall deep-links: context without dark patterns.
///
/// Always show Free continues, restore, manage/cancel on the paywall itself.
/// Query params only *highlight* a recommended plan and explain the gate.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../domain/entitlements.dart';

/// Builds `/paywall?...` with optional gate / plan / reason / returnTo.
String paywallLocation({
  String? gate,
  Plan? plan,
  String? reason,
  String? returnTo,
}) {
  final params = <String, String>{
    if (gate != null && gate.isNotEmpty) 'gate': gate,
    if (plan != null) 'plan': plan.name,
    if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    if (returnTo != null && returnTo.isNotEmpty) 'returnTo': returnTo,
  };
  return Uri(path: '/paywall', queryParameters: params).toString();
}

/// Resolve gate → minimum plan for contextual highlight.
Plan? planForGate(String? gateKey) {
  if (gateKey == null) return null;
  return gates[gateKey]?.requiredPlan;
}

String? pitchForGate(String? gateKey) {
  if (gateKey == null) return null;
  return gates[gateKey]?.pitch;
}

/// Push paywall with optional context. Prefer this over bare `/paywall`.
Future<T?> pushPaywall<T extends Object?>(
  BuildContext context, {
  String? gate,
  Plan? plan,
  String? reason,
  String? returnTo,
}) {
  final resolvedPlan = plan ?? planForGate(gate);
  final resolvedReason = reason ?? pitchForGate(gate);
  return context.push<T>(
    paywallLocation(
      gate: gate,
      plan: resolvedPlan,
      reason: resolvedReason,
      returnTo: returnTo,
    ),
  );
}
