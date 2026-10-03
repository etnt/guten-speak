import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Checks the Guten-Speak GitHub Releases feed for a newer app version.
/// `main()` overrides this with a persistent check store; tests can inject a
/// fake checker without reaching the network.
final releaseCheckerProvider = Provider<ReleaseChecker>((ref) {
  return ReleaseChecker(
    owner: 'etnt',
    repo: 'guten-speak',
    currentVersion: AppConstants.appVersion,
  );
});
