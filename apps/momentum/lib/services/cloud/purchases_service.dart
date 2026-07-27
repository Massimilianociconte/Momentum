/// Abbonamenti via RevenueCat + IAP store (PRD I5).
///
/// Con REVENUECAT_*_KEY configurate: acquisto reale via store.
/// Senza chiavi: nessun acquisto reale; l'attivazione locale resta confinata
/// al livello UI per debug/test espliciti.
///
/// Setup dashboard RevenueCat richiesto (una volta sola):
///  - Entitlements: "plus", "pro", "coach"
///  - Offerings: default con package mensili $rc_monthly per prodotto
///  - Prodotti store: rallymate_plus_monthly, rallymate_pro_monthly,
///    rallymate_coach_monthly
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/entitlements.dart';
import 'cloud_config.dart';

/// Runs a non-critical billing side effect without allowing SDK setup failures
/// to break authentication or local account cleanup.
@visibleForTesting
Future<bool> runBillingBestEffort({
  required Future<void> Function() initialize,
  required Future<void> Function() operation,
}) async {
  try {
    await initialize();
    await operation();
    return true;
  } catch (_) {
    return false;
  }
}

/// Esito esplicito di un cambio identita nel billing SDK.
///
/// [operationSucceeded] descrive la chiamata `logIn`/`logOut`; [identityVerified]
/// richiede anche che l'identita riletta dal SDK sia quella attesa. Tenerli
/// separati evita che un errore best-effort venga scambiato per un cambio utente
/// riuscito.
class BillingIdentityResult {
  const BillingIdentityResult({
    required this.operationSucceeded,
    required this.identityVerified,
    this.appUserId,
  });

  final bool operationSucceeded;
  final bool identityVerified;
  final String? appUserId;

  bool get success => operationSucceeded && identityVerified;
}

/// Snapshot del piano utilizzabile solo se l'identita RevenueCat e rimasta
/// allineata per tutta la lettura di CustomerInfo.
class VerifiedStorePlan {
  const VerifiedStorePlan({
    required this.plan,
    required this.identityVerified,
    this.appUserId,
  });

  final Plan? plan;
  final bool identityVerified;
  final String? appUserId;
}

/// Gli acquisti cloud devono usare l'UUID Supabase, mai l'identita anonima
/// generata da RevenueCat: il webhook non potrebbe associarla a un profilo.
bool isAuthenticatedBillingUserId(String? value) {
  final userId = value?.trim() ?? '';
  return userId.isNotEmpty && !userId.startsWith(r'$RCAnonymousID');
}

/// Helper iniettabile usato anche dai test di account switching.
@visibleForTesting
Future<BillingIdentityResult> switchBillingIdentity({
  required String expectedAppUserId,
  required Future<void> Function() initialize,
  required Future<void> Function(String appUserId) logIn,
  required Future<String> Function() readAppUserId,
}) async {
  if (!isAuthenticatedBillingUserId(expectedAppUserId)) {
    return const BillingIdentityResult(
      operationSucceeded: false,
      identityVerified: false,
    );
  }
  var operationSucceeded = false;
  try {
    await initialize();
    await logIn(expectedAppUserId);
    operationSucceeded = true;
  } catch (_) {
    // Verifica comunque lo stato effettivo: alcuni bridge possono completare
    // il cambio identita prima di propagare un errore di rete al chiamante.
  }

  try {
    final actual = await readAppUserId();
    return BillingIdentityResult(
      operationSucceeded: operationSucceeded,
      identityVerified: actual == expectedAppUserId,
      appUserId: actual,
    );
  } catch (_) {
    return BillingIdentityResult(
      operationSucceeded: operationSucceeded,
      identityVerified: false,
    );
  }
}

/// Variante iniettabile del logout, con verifica esplicita che RevenueCat sia
/// passato a un'identita anonima. Un logout gia anonimo e idempotente.
@visibleForTesting
Future<BillingIdentityResult> clearBillingIdentity({
  required Future<void> Function() initialize,
  required Future<void> Function() logOut,
  required Future<String> Function() readAppUserId,
  required Future<bool> Function() readIsAnonymous,
}) async {
  var operationSucceeded = false;
  try {
    await initialize();
    if (!await readIsAnonymous()) await logOut();
    operationSucceeded = true;
  } catch (_) {
    // La verifica sottostante distingue un errore transitorio da un logout che
    // ha comunque portato il SDK nello stato anonimo atteso.
  }

  try {
    final appUserId = await readAppUserId();
    final anonymous = await readIsAnonymous();
    return BillingIdentityResult(
      operationSucceeded: operationSucceeded,
      identityVerified: anonymous,
      appUserId: appUserId,
    );
  } catch (_) {
    return BillingIdentityResult(
      operationSucceeded: operationSucceeded,
      identityVerified: false,
    );
  }
}

/// Legge il piano solo se l'appUserID coincide prima e dopo CustomerInfo.
/// Il secondo controllo chiude anche la finestra di race con un logout/login
/// concorrente mentre RevenueCat restituisce una risposta dalla cache.
@visibleForTesting
Future<VerifiedStorePlan> readStorePlanForIdentity({
  required String expectedAppUserId,
  required Future<String> Function() readAppUserId,
  required Future<Plan> Function() readPlan,
}) async {
  if (!isAuthenticatedBillingUserId(expectedAppUserId)) {
    return const VerifiedStorePlan(plan: null, identityVerified: false);
  }
  final before = await readAppUserId();
  if (before != expectedAppUserId) {
    return VerifiedStorePlan(
      plan: null,
      identityVerified: false,
      appUserId: before,
    );
  }

  final plan = await readPlan();
  final after = await readAppUserId();
  if (after != expectedAppUserId) {
    return VerifiedStorePlan(
      plan: null,
      identityVerified: false,
      appUserId: after,
    );
  }
  return VerifiedStorePlan(
    plan: plan,
    identityVerified: true,
    appUserId: after,
  );
}

/// Applica al mirror locale esclusivamente uno snapshot con identita verificata.
/// Ritorna `true` solo se ha effettuato una scrittura.
///
/// [allowFreeDowngrade]: se `false` (default per sync in background), non
/// sovrascrive un piano a pagamento locale con free (RC lag / cache). Usa
/// `true` solo dopo restore/purchase espliciti.
Future<bool> applyVerifiedStorePlan({
  required String? supabaseUserId,
  required VerifiedStorePlan snapshot,
  required Future<String?> Function() readAccountRole,
  required Future<Plan> Function() readCurrentPlan,
  required Future<void> Function(Plan plan) writePlan,
  Future<bool> Function()? readPremiumOverride,
  bool allowFreeDowngrade = false,
}) async {
  final storePlan = snapshot.plan;
  if (!isAuthenticatedBillingUserId(supabaseUserId) ||
      !snapshot.identityVerified ||
      snapshot.appUserId != supabaseUserId ||
      storePlan == null) {
    return false;
  }
  if (storePlan == Plan.free) {
    final role = await readAccountRole();
    if (role == 'admin' || role == 'super_admin') return false;
    if (await readPremiumOverride?.call() ?? false) return false;
    if (!allowFreeDowngrade) {
      final current = await readCurrentPlan();
      if (current != Plan.free) return false;
    }
  }
  if (storePlan == await readCurrentPlan()) return false;
  await writePlan(storePlan);
  // Call-site writePlan may no-op (auth/link checks); confirm mirror moved.
  return storePlan == await readCurrentPlan();
}

class StorePlanInfo {
  const StorePlanInfo({
    required this.plan,
    required this.productId,
    required this.title,
    required this.displayPrice,
    required this.periodLabel,
  });

  final Plan plan;
  final String productId;
  final String title;
  final String displayPrice;
  final String periodLabel;
}

abstract final class PurchasesService {
  static bool _initialized = false;
  static Future<void>? _initializing;

  static String get _apiKey => !kIsWeb && Platform.isIOS
      ? CloudConfig.revenueCatIosKey
      : CloudConfig.revenueCatAndroidKey;

  static bool get configured => _apiKey.isNotEmpty;

  static Future<void> init() {
    if (!configured || _initialized) return Future.value();
    return _initializing ??= _configure();
  }

  static Future<void> _configure() async {
    try {
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _initialized = true;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  /// Compra il piano. Ritorna null se ok, altrimenti il messaggio errore.
  static Future<String?> purchase(
    Plan plan, {
    required String expectedAppUserId,
  }) async {
    if (!isAuthenticatedBillingUserId(expectedAppUserId)) {
      return 'Accedi al tuo account Momentum prima di acquistare.';
    }
    if (!configured) return 'Acquisti temporaneamente non disponibili.';
    try {
      await init();
      if (await Purchases.appUserID != expectedAppUserId) {
        return 'Sessione acquisti non allineata. Esci e accedi di nuovo.';
      }
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return 'Offerte temporaneamente non disponibili.';
      final pkg = _packageForPlan(current, plan);
      if (pkg == null) {
        return 'Il piano ${plan.label} non è temporaneamente acquistabile.';
      }
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      final info = result.customerInfo;
      if (await Purchases.appUserID != expectedAppUserId) {
        return 'Sessione acquisti cambiata. Verifica il piano dal profilo.';
      }
      return info.entitlements.active.containsKey(plan.name)
          ? null
          : 'Acquisto in verifica. Usa Ripristina acquisti tra pochi istanti.';
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return 'Acquisto annullato';
      }
      return e.message ?? 'Acquisto non riuscito. Riprova.';
    } catch (_) {
      return 'Acquisto non riuscito. Riprova.';
    }
  }

  static Future<Map<Plan, StorePlanInfo>> planInfo() async {
    if (!configured) return const {};
    try {
      await init();
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return const {};
      final info = <Plan, StorePlanInfo>{};
      for (final plan in [Plan.plus, Plan.pro, Plan.coach]) {
        final pkg = _packageForPlan(current, plan);
        if (pkg == null) continue;
        info[plan] = StorePlanInfo(
          plan: plan,
          productId: pkg.storeProduct.identifier,
          title: pkg.storeProduct.title,
          displayPrice: pkg.storeProduct.priceString,
          periodLabel: _periodLabel(pkg.storeProduct.subscriptionPeriod),
        );
      }
      return info;
    } catch (_) {
      return const {};
    }
  }

  /// Piano attivo secondo lo store (per restore/sync all'avvio).
  static Future<Plan?> activePlan({String? expectedAppUserId}) async {
    if (!configured) return null;
    try {
      await init();
      Future<Plan> readPlan() async {
        final info = await Purchases.getCustomerInfo();
        for (final plan in [Plan.coach, Plan.pro, Plan.plus]) {
          if (info.entitlements.active.containsKey(plan.name)) return plan;
        }
        return Plan.free;
      }

      if (expectedAppUserId == null) return readPlan();
      final verified = await _activePlanForUser(expectedAppUserId, readPlan);
      return verified.identityVerified ? verified.plan : null;
    } catch (_) {
      return null;
    }
  }

  /// Piano e prova di identita per i call-site che possono aggiornare il mirror
  /// locale. A differenza di [activePlan], non appiattisce un mismatch a `null`.
  static Future<VerifiedStorePlan> verifiedActivePlan(
    String expectedAppUserId,
  ) async {
    if (!configured) {
      return const VerifiedStorePlan(plan: null, identityVerified: false);
    }
    try {
      await init();
      return _activePlanForUser(expectedAppUserId, () async {
        final info = await Purchases.getCustomerInfo();
        for (final plan in [Plan.coach, Plan.pro, Plan.plus]) {
          if (info.entitlements.active.containsKey(plan.name)) return plan;
        }
        return Plan.free;
      });
    } catch (_) {
      return const VerifiedStorePlan(plan: null, identityVerified: false);
    }
  }

  static Future<VerifiedStorePlan> _activePlanForUser(
    String expectedAppUserId,
    Future<Plan> Function() readPlan,
  ) => readStorePlanForIdentity(
    expectedAppUserId: expectedAppUserId,
    readAppUserId: () => Purchases.appUserID,
    readPlan: readPlan,
  );

  /// Collega l'utente store all'account cloud (per il webhook → set_plan).
  static Future<BillingIdentityResult> logIn(String supabaseUserId) async {
    if (!configured) {
      return const BillingIdentityResult(
        operationSucceeded: false,
        identityVerified: false,
      );
    }
    return switchBillingIdentity(
      expectedAppUserId: supabaseUserId,
      initialize: init,
      logIn: (appUserId) async {
        await Purchases.logIn(appUserId);
      },
      readAppUserId: () => Purchases.appUserID,
    );
  }

  /// Scollega l'utente store al logout (torna all'app-user anonimo, così un
  /// altro account sullo stesso device non eredita gli entitlement).
  static Future<BillingIdentityResult> logOut() async {
    if (!configured) {
      return const BillingIdentityResult(
        operationSucceeded: false,
        identityVerified: false,
      );
    }
    return clearBillingIdentity(
      initialize: init,
      logOut: () async {
        await Purchases.logOut();
      },
      readAppUserId: () => Purchases.appUserID,
      readIsAnonymous: () => Purchases.isAnonymous,
    );
  }

  static Future<String?> restore({required String expectedAppUserId}) async {
    if (!isAuthenticatedBillingUserId(expectedAppUserId)) {
      return 'Accedi al tuo account Momentum prima di ripristinare.';
    }
    if (!configured) return 'Acquisti temporaneamente non disponibili.';
    try {
      await init();
      if (await Purchases.appUserID != expectedAppUserId) {
        return 'Sessione acquisti non allineata. Esci e accedi di nuovo.';
      }
      await Purchases.restorePurchases();
      if (await Purchases.appUserID != expectedAppUserId) {
        return 'Sessione acquisti cambiata. Riprova dopo un nuovo accesso.';
      }
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Restore non riuscito';
    } catch (_) {
      return 'Restore non riuscito. Riprova.';
    }
  }

  static Package? _packageForPlan(Offering offering, Plan plan) {
    final name = plan.name.toLowerCase();
    // Ogni matcher è valutato su TUTTI i package prima di degradare al
    // successivo: un id "quasi giusto" incontrato per primo non deve vincere
    // sull'id canonico. Niente `contains` nudo: "pro" è substring di "promo".
    final matchers = <bool Function(String productId, String packageId)>[
      (productId, _) => productId == 'rallymate_${name}_monthly',
      (productId, _) => productId.endsWith('_${name}_monthly'),
      (productId, _) =>
          productId == 'rallymate_$name' ||
          productId.startsWith('rallymate_${name}_'),
      (_, packageId) => packageId == name,
    ];
    for (final matches in matchers) {
      for (final package in offering.availablePackages) {
        if (matches(
          package.storeProduct.identifier.toLowerCase(),
          package.identifier.toLowerCase(),
        )) {
          return package;
        }
      }
    }
    return null;
  }

  static String _periodLabel(String? period) => switch (period) {
    'P1W' => 'settimanale',
    'P1M' => 'mensile',
    'P2M' => 'ogni 2 mesi',
    'P3M' => 'trimestrale',
    'P6M' => 'semestrale',
    'P1Y' => 'annuale',
    _ => 'periodo indicato dallo store',
  };
}
