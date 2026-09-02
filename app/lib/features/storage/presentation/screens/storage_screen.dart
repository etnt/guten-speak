import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/storage_usage.dart';
import '../providers/storage_providers.dart';

/// Shows on-device storage used by the TTS model, narrated audio (per book) and
/// imported voices, with actions to delete/clear each to reclaim space.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: usage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not read storage usage.\n$error'),
          ),
        ),
        data: (data) => _StorageBody(data),
      ),
    );
  }
}

class _StorageBody extends ConsumerWidget {
  const _StorageBody(this.usage);

  final StorageUsage usage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(storageControllerProvider.notifier);

    return ListView(
      children: [
        _SectionHeader('Total • ${formatBytes(usage.totalBytes)}'),

        const _SectionHeader('Voice model'),
        if (!usage.anyModelInstalled)
          const ListTile(
            leading: Icon(Icons.graphic_eq_outlined),
            title: Text('Neural voice model'),
            subtitle: Text('Not installed'),
          )
        else
          for (final model in usage.models)
            if (model.installed)
              ListTile(
                leading: const Icon(Icons.graphic_eq_outlined),
                title: Text(model.label),
                subtitle: Text('Installed • ${formatBytes(model.bytes)}'),
                trailing: IconButton(
                  tooltip: 'Delete model',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => unawaited(
                    _confirmDeleteModel(context, controller, model),
                  ),
                ),
              ),

        const Divider(),
        Row(
          children: [
            const Expanded(child: _SectionHeader('Narrated audio')),
            if (usage.perBookAudio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear all'),
                  onPressed: () =>
                      unawaited(_confirmClearAudio(context, controller)),
                ),
              ),
          ],
        ),
        if (usage.perBookAudio.isEmpty)
          const ListTile(
            leading: Icon(Icons.audiotrack_outlined),
            title: Text('No narrated audio yet'),
            subtitle: Text('Cached narration clips appear here per book'),
          )
        else
          for (final book in usage.perBookAudio)
            ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(formatBytes(book.bytes)),
              trailing: IconButton(
                tooltip: 'Delete audio',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => unawaited(
                  _confirmDeleteBookAudio(context, controller, book),
                ),
              ),
            ),

        const Divider(),
        const _SectionHeader('Voices'),
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: const Text('Imported voices'),
          subtitle: Text(
            usage.voiceCount == 0
                ? 'No imported voices'
                : '${usage.voiceCount} imported • ${formatBytes(usage.voicesBytes)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppConstants.routeVoices),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteModel(
    BuildContext context,
    StorageController controller,
    ModelUsage model,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete voice model?',
      message:
          'The ${model.label} (${formatBytes(model.bytes)}) will be removed. '
          'It downloads again the next time you start narration with that '
          'engine.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await controller.deleteModel(model.id);
  }

  Future<void> _confirmClearAudio(
    BuildContext context,
    StorageController controller,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear all narrated audio?',
      message:
          'Cached narration for every book will be deleted. It is '
          're-rendered on demand the next time you listen.',
      confirmLabel: 'Clear all',
    );
    if (confirmed) await controller.clearAllAudio();
  }

  Future<void> _confirmDeleteBookAudio(
    BuildContext context,
    StorageController controller,
    BookAudioUsage book,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete narrated audio?',
      message:
          'Cached narration for "${book.title}" will be deleted. It is '
          're-rendered on demand the next time you listen.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await controller.deleteBookAudio(book.bookId);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
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

/// Formats a byte count as B / KB / MB / GB with one decimal place for the
/// larger units.
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}
