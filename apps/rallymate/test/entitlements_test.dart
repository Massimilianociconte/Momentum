import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/domain/entitlements.dart';

void main() {
  test('free account cannot use cloud wearable integrations', () {
    const entitlements = Entitlements(Plan.free);
    expect(entitlements.duoMode, isFalse);
    expect(entitlements.healthConnectSync, isFalse);
    expect(entitlements.llmAssistant, isFalse);
  });

  test('premium override unlocks every paid capability for test admins', () {
    const entitlements = Entitlements(Plan.free, premiumOverride: true);
    expect(entitlements.hasAtLeast(Plan.coach), isTrue);
    expect(entitlements.duoMode, isTrue);
    expect(entitlements.cloudBackup, isTrue);
    expect(entitlements.healthConnectSync, isTrue);
    expect(entitlements.llmAssistant, isTrue);
    expect(entitlements.coachTools, isTrue);
    expect(entitlements.maxTeams, greaterThan(1000));
    expect(entitlements.pdfExport, isTrue);
    expect(entitlements.advancedDifficulty, isTrue);
    expect(entitlements.friendGroups, isTrue);
  });

  // PRD 8: export PDF è Plus; difficoltà advanced e gruppi/classifiche
  // private sono Pro. Le diciture del paywall dipendono da questi gate.
  test('plus unlocks pdf export but not the pro tier features', () {
    const plus = Entitlements(Plan.plus);
    expect(plus.pdfExport, isTrue);
    expect(plus.advancedDifficulty, isFalse);
    expect(plus.friendGroups, isFalse);
  });

  test('pro unlocks difficulty advanced and friend groups', () {
    const pro = Entitlements(Plan.pro);
    expect(pro.pdfExport, isTrue);
    expect(pro.advancedDifficulty, isTrue);
    expect(pro.friendGroups, isTrue);
    expect(pro.coachTools, isFalse);
  });

  test('every paywall gate key has pitch and required plan', () {
    for (final key in [
      'pdf_export',
      'difficulty_advanced',
      'friend_groups',
      'coach_tools',
    ]) {
      expect(gates[key], isNotNull, reason: 'gate $key mancante');
      expect(gates[key]!.pitch, isNotEmpty);
    }
    expect(gates['pdf_export']!.requiredPlan, Plan.plus);
    expect(gates['difficulty_advanced']!.requiredPlan, Plan.pro);
    expect(gates['friend_groups']!.requiredPlan, Plan.pro);
  });
}
