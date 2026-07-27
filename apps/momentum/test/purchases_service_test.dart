import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/domain/entitlements.dart';
import 'package:rallymate/services/cloud/purchases_service.dart';

void main() {
  test(
    'billing init failure never runs or leaks a best-effort side effect',
    () async {
      var operationCalled = false;

      final ok = await runBillingBestEffort(
        initialize: () async => throw StateError('sdk_init_failed'),
        operation: () async => operationCalled = true,
      );

      expect(ok, isFalse);
      expect(operationCalled, isFalse);
    },
  );

  test(
    'billing operation failure is contained after successful init',
    () async {
      final ok = await runBillingBestEffort(
        initialize: () async {},
        operation: () async => throw StateError('sdk_operation_failed'),
      );

      expect(ok, isFalse);
    },
  );

  test(
    'failed A to B login cannot promote B from cached A CustomerInfo',
    () async {
      var currentAppUserId = 'user-a';
      var customerInfoReads = 0;

      final login = await switchBillingIdentity(
        expectedAppUserId: 'user-b',
        initialize: () async {},
        logIn: (_) async => throw StateError('identity_switch_failed'),
        readAppUserId: () async => currentAppUserId,
      );
      expect(login.operationSucceeded, isFalse);
      expect(login.identityVerified, isFalse);
      expect(login.appUserId, 'user-a');

      final cached = await readStorePlanForIdentity(
        expectedAppUserId: 'user-b',
        readAppUserId: () async => currentAppUserId,
        readPlan: () async {
          customerInfoReads++;
          return Plan.pro;
        },
      );

      expect(cached.identityVerified, isFalse);
      expect(cached.plan, isNull);
      expect(customerInfoReads, 0);

      var mirroredPlan = Plan.free;
      var mirrorWrites = 0;
      final wrote = await applyVerifiedStorePlan(
        supabaseUserId: 'user-b',
        snapshot: cached,
        readAccountRole: () async => 'user',
        readCurrentPlan: () async => mirroredPlan,
        writePlan: (plan) async {
          mirrorWrites++;
          mirroredPlan = plan;
        },
      );
      expect(wrote, isFalse);
      expect(mirrorWrites, 0);
      expect(mirroredPlan, Plan.free);
    },
  );

  test('identity switch during CustomerInfo read is fail closed', () async {
    var reads = 0;
    final cached = await readStorePlanForIdentity(
      expectedAppUserId: 'user-b',
      readAppUserId: () async => reads++ == 0 ? 'user-b' : 'user-a',
      readPlan: () async => Plan.pro,
    );

    expect(cached.identityVerified, isFalse);
    expect(cached.plan, isNull);
    expect(cached.appUserId, 'user-a');
  });

  test(
    'logout reports both operation and anonymous identity verification',
    () async {
      var anonymous = false;
      var appUserId = 'user-a';
      final result = await clearBillingIdentity(
        initialize: () async {},
        logOut: () async {
          anonymous = true;
          appUserId = r'$RCAnonymousID:test';
        },
        readAppUserId: () async => appUserId,
        readIsAnonymous: () async => anonymous,
      );

      expect(result.operationSucceeded, isTrue);
      expect(result.identityVerified, isTrue);
      expect(result.success, isTrue);
      expect(result.appUserId, startsWith(r'$RCAnonymousID:'));
    },
  );

  test(
    'anonymous RevenueCat identity cannot purchase or update the mirror',
    () async {
      expect(isAuthenticatedBillingUserId(null), isFalse);
      expect(isAuthenticatedBillingUserId(''), isFalse);
      expect(isAuthenticatedBillingUserId(r'$RCAnonymousID:device'), isFalse);
      expect(
        await PurchasesService.purchase(
          Plan.pro,
          expectedAppUserId: r'$RCAnonymousID:device',
        ),
        contains('Accedi al tuo account'),
      );
      expect(
        await PurchasesService.restore(
          expectedAppUserId: r'$RCAnonymousID:device',
        ),
        contains('Accedi al tuo account'),
      );

      var writes = 0;
      final wrote = await applyVerifiedStorePlan(
        supabaseUserId: null,
        snapshot: const VerifiedStorePlan(
          plan: Plan.pro,
          identityVerified: true,
          appUserId: r'$RCAnonymousID:device',
        ),
        readAccountRole: () async => 'user',
        readCurrentPlan: () async => Plan.free,
        writePlan: (_) async => writes++,
      );

      expect(wrote, isFalse);
      expect(writes, 0);
    },
  );
}
