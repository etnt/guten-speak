import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Narrator voices'),
            subtitle: const Text('Manage and import voices for narration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppConstants.routeVoices),
          ),
        ],
      ),
    );
  }
}
