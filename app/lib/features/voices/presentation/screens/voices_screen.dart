import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/voice.dart';
import '../providers/voice_providers.dart';

/// Manage the narrator voice library: pick the active voice, import a `.wav`
/// sample under a name, and delete user voices. Built-in voices (Reginald
/// Ashworth and Deja Thoris) are always present and cannot be deleted.
class VoicesScreen extends ConsumerWidget {
  const VoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(voicesControllerProvider);
    final selected = ref.watch(selectedVoiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Narrator voices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importVoice(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add voice'),
      ),
      body: voicesAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(voicesControllerProvider),
        ),
        data: (voices) {
          final effectiveSelectedId =
              selected?.id ?? (voices.isNotEmpty ? voices.first.id : null);
          return RadioGroup<String>(
            groupValue: effectiveSelectedId,
            onChanged: (id) {
              if (id == null) return;
              final voice = voices.firstWhere((v) => v.id == id);
              ref.read(selectedVoiceProvider.notifier).select(voice);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final voice in voices)
                  RadioListTile<String>(
                    value: voice.id,
                    title: Text(voice.name),
                    subtitle: Text(voice.builtIn ? 'Built-in' : 'Imported'),
                    secondary: voice.builtIn
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete voice',
                            onPressed: () =>
                                _confirmDelete(context, ref, voice),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _importVoice(BuildContext context, WidgetRef ref) async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['wav'],
    );
    if (files.isEmpty) return;
    final picked = files.single;
    final path = picked.path;
    if (path == null || !context.mounted) return;

    final suggested = picked.name.replaceAll(
      RegExp(r'\.wav$', caseSensitive: false),
      '',
    );
    final name = await _promptName(context, initial: suggested);
    if (name == null || name.trim().isEmpty) return;

    try {
      await ref
          .read(voicesControllerProvider.notifier)
          .addVoice(name: name.trim(), sourceWavPath: path);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import voice: $error')),
        );
      }
    }
  }

  Future<String?> _promptName(BuildContext context, {required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this voice'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Grandpa'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Voice voice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${voice.name}"?'),
        content: const Text('This removes the imported voice sample.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(voicesControllerProvider.notifier).removeVoice(voice.id);
    }
  }
}
