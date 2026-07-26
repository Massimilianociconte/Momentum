/// Typed destinations for links that must land on a precise in-page section.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum ProfileSectionTarget {
  plan,
  visibility,
  smartwatch,
  notifications,
  health,
  account,
  backup;

  static ProfileSectionTarget? fromQuery(String? value) {
    for (final section in values) {
      if (section.name == value) return section;
    }
    return null;
  }

  String get label => switch (this) {
    ProfileSectionTarget.plan => 'Piano e acquisti',
    ProfileSectionTarget.visibility => 'Visibilita social',
    ProfileSectionTarget.smartwatch => 'Collegamento smartwatch',
    ProfileSectionTarget.notifications => 'Notifiche',
    ProfileSectionTarget.health => 'Salute e fitness',
    ProfileSectionTarget.account => 'Account',
    ProfileSectionTarget.backup => 'Backup dati',
  };
}

abstract final class AppLocations {
  static const profile = '/profile';
  static const home = '/home';
  static const friends = '/friends';
  static const social = '/social';
  static const devices = '/devices';
  static const teams = '/teams';
  static const auth = '/auth';

  static String profileSection(ProfileSectionTarget section) =>
      Uri(path: profile, queryParameters: {'focus': section.name}).toString();

  static String friendsTab(String tab) =>
      Uri(path: friends, queryParameters: {'tab': tab}).toString();

  static String socialFocus(String focus) =>
      Uri(path: social, queryParameters: {'focus': focus}).toString();
}

/// Safe stack-aware back navigation for top-level and deep-linked routes.
///
/// `context.go` deep links leave an empty stack; without a fallback the
/// system back gesture and AppBar leading disappear or trap the user.
abstract final class AppNavigation {
  static void popOrGo(BuildContext context, {String fallback = AppLocations.home}) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final target = fallback.startsWith('/') ? fallback : AppLocations.home;
    context.go(target);
  }
}
