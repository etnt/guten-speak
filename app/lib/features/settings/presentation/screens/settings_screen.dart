import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../dictionary/presentation/providers/dictionary_providers.dart';
import '../../../narration/presentation/providers/narration_settings_providers.dart';
import '../../../voices/presentation/providers/voice_providers.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final selectedVoice = ref.watch(selectedVoiceProvider);
    final speed = ref.watch(narrationSpeedProvider);
    final headStart = ref.watch(headStartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark theme'),
            subtitle: const Text('Use the dark app theme'),
            value: themeMode == ThemeMode.dark,
            onChanged: (isDark) => ref
                .read(themeModeProvider.notifier)
                .set(isDark ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),
          const _SectionHeader('Narration'),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Narrator voices'),
            subtitle: Text(
              selectedVoice == null
                  ? 'Manage and import voices for narration'
                  : 'Default: ${selectedVoice.name}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppConstants.routeVoices),
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Default playback speed'),
            subtitle: const Text('Speed applied when a new book starts'),
            trailing: DropdownButton<double>(
              value: speed,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in NarrationSpeedNotifier.options)
                  DropdownMenuItem<double>(
                    value: option,
                    child: Text(_formatSpeed(option)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(narrationSpeedProvider.notifier).set(value);
                }
              },
            ),
          ),
          _HeadStartTile(
            value: headStart,
            onChanged: (value) =>
                ref.read(headStartProvider.notifier).set(value),
          ),
          const Divider(),
          const _SectionHeader('Reading'),
          const _DictionaryTile(),
          const Divider(),
          const _SectionHeader('Storage'),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Manage storage'),
            subtitle: const Text('Model, narrated audio and voice sizes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppConstants.routeStorage),
          ),
        ],
      ),
    );
  }

  static String _formatSpeed(double value) =>
      value == value.truncateToDouble() ? '${value.toInt()}×' : '$value×';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A +/- stepper for the default head-start (pre-render) size.
class _HeadStartTile extends StatelessWidget {
  const _HeadStartTile({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.playlist_add_check_outlined),
      title: const Text('Head start (pre-render)'),
      subtitle: const Text('Sections prepared before playback begins'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > HeadStartNotifier.min
                ? () => onChanged(value - 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: value < HeadStartNotifier.max
                ? () => onChanged(value + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// Shows the optional offline dictionary's status with download/remove actions.
class _DictionaryTile extends ConsumerWidget {
  const _DictionaryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(dictionaryInstalledProvider);
    final download = ref.watch(dictionaryDownloadControllerProvider);
    final controller = ref.read(dictionaryDownloadControllerProvider.notifier);

    if (download.isDownloading) {
      final pct = download.fraction != null
          ? ' ${(download.fraction! * 100).round()}%'
          : '';
      return ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text('Offline dictionary'),
        subtitle: Text('Downloading…$pct'),
        trailing: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: controller.cancel,
        ),
      );
    }

    final isInstalled = installed.valueOrNull ?? false;
    if (isInstalled) {
      final bytes = ref.watch(dictionaryBytesProvider).valueOrNull ?? 0;
      return ListTile(
        leading: const Icon(Icons.menu_book),
        title: const Text('Offline dictionary'),
        subtitle: Text('Installed • ${_formatBytes(bytes)}'),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => unawaited(_confirmRemove(context, controller)),
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: const Text('Offline dictionary'),
      subtitle: Text(
        download.error ??
            'Not installed — one-time ~15 MB download for word look-ups',
      ),
      trailing: const Icon(Icons.download),
      onTap: () => unawaited(controller.download()),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    DictionaryDownloadController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove dictionary?'),
        content: const Text(
          'The offline dictionary will be deleted. You can download it again '
          'later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.remove();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
