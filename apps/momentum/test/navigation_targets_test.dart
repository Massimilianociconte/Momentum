import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/core/navigation_targets.dart';

void main() {
  test('profile section route keeps a precise destination', () {
    expect(
      AppLocations.profileSection(ProfileSectionTarget.smartwatch),
      '/profile?focus=smartwatch',
    );
    expect(
      ProfileSectionTarget.fromQuery('smartwatch'),
      ProfileSectionTarget.smartwatch,
    );
  });

  test('unknown profile section is ignored safely', () {
    expect(ProfileSectionTarget.fromQuery('missing'), isNull);
    expect(ProfileSectionTarget.fromQuery(null), isNull);
  });

  test('social and friends deep-link helpers keep stable query shapes', () {
    expect(AppLocations.friendsTab('requests'), '/friends?tab=requests');
    expect(AppLocations.socialFocus('inbox'), '/social?focus=inbox');
  });
}
