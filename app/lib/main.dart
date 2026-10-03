import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'core/licenses/third_party_licenses.dart';
import 'core/update/update_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        releaseCheckerProvider.overrideWithValue(
          ReleaseChecker(
            owner: 'etnt',
            repo: 'guten-speak',
            currentVersion: AppConstants.appVersion,
            // Avoid a GitHub request on every launch; successful checks are
            // throttled across restarts, while errors remain retryable.
            checkStore: SharedPrefsUpdateCheckStore(prefs),
          ),
        ),
      ],
      child: const GutenSpeakApp(),
    ),
  );
}
