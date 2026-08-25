import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'model_manager.dart';
import 'tts_service.dart';
import 'voice_library.dart';

void main() {
  runApp(const PocApp());
}

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guten-Speak PoC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SpikeScreen(),
    );
  }
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final ModelManager _modelManager = ModelManager();
  final TtsService _tts = TtsService();
  final VoiceLibrary _library = VoiceLibrary();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _textController = TextEditingController(
    text:
        'Hello!\n'
        'guten-speak is a mobile app that searches Project Gutenberg, downloads books,\n'
        'and reads them aloud with your favorite narrator voice.',
  );

  String _status = 'Tap "Prepare model" to download and load PocketTTS.';
  double? _downloadFraction;
  bool _busy = false;
  Voice? _selectedVoice;
  int _numSteps = 28;
  double _temperature = 0.20;
  SpeakResult? _lastResult;

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    _tts.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _prepareModel() async {
    setState(() {
      _busy = true;
      _downloadFraction = null;
    });
    try {
      final paths = await _modelManager.ensureModel(
        onStatus: _setStatus,
        onProgress: (f) {
          if (mounted) setState(() => _downloadFraction = f);
        },
      );
      _setStatus('Loading model into memory…');
      await _tts.init(paths);
      await _library.load();
      setState(() {
        _selectedVoice ??= _library.voices.first;
        _status = 'Model ready. Pick or add a voice, then Speak.';
      });
    } catch (e) {
      _setStatus('Error preparing model: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _downloadFraction = null;
        });
      }
    }
  }

  /// Imports a `.wav` sample into the voice library and selects it.
  ///
  /// Voice input is upload-only: a clean, loud `.wav` clones far more reliably
  /// than a phone recording (see plan §11). MP3 needs a PCM decoder (not wired).
  Future<void> _addVoice() async {
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: 'Choose a voice sample (.wav)',
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    if (file == null) return; // user canceled
    final path = file.path;
    if (path == null || !await File(path).exists()) {
      _setStatus('Could not read the selected file.');
      return;
    }
    final defaultName = file.name.replaceAll(
      RegExp(r'\.wav$', caseSensitive: false),
      '',
    );
    final name = await _promptVoiceName(defaultName);
    if (name == null || name.trim().isEmpty) return;
    try {
      final voice = await _library.add(name: name.trim(), sourceWavPath: path);
      setState(() {
        _selectedVoice = voice;
        _status = 'Added voice "${voice.name}". Ready to Speak.';
      });
    } catch (e) {
      _setStatus('Could not save the voice: $e');
    }
  }

  /// Deletes a user voice after confirmation.
  Future<void> _deleteVoice(Voice voice) async {
    if (voice.builtIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete voice?'),
        content: Text('Remove "${voice.name}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _library.remove(voice.id);
    setState(() {
      if (_selectedVoice?.id == voice.id) {
        _selectedVoice = _library.voices.first;
      }
      _status = 'Deleted voice "${voice.name}".';
    });
  }

  /// Prompts for a voice name, pre-filled with [initial].
  Future<String?> _promptVoiceName(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this voice'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Voice name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _speak() async {
    final reference = _selectedVoice?.wavPath;
    if (!_tts.isReady || reference == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _setStatus('Type some text to speak.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Generating speech (cloning voice)…';
    });

    try {
      final dir = await getTemporaryDirectory();
      await dir.create(recursive: true);
      final outPath =
          '${dir.path}/out_${DateTime.now().millisecondsSinceEpoch}.wav';
      final result = await _tts.speak(
        text: text,
        referenceWavPath: reference,
        outputWavPath: outPath,
        numSteps: _numSteps,
        temperature: _temperature,
      );
      setState(() {
        _lastResult = result;
        _status = 'Done. Playing back.';
      });
      await _player.play(DeviceFileSource(outPath));
    } catch (e) {
      _setStatus('Error during synthesis: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildVoiceCard(BuildContext context, bool modelReady) {
    final voices = _library.voices;
    final selected = _selectedVoice;
    final canManage = modelReady && !_busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('2. Voice', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: canManage ? _addVoice : null,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Add (.wav)'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (voices.isEmpty)
              const Text('Prepare the model to load voices.')
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selected?.id,
                      onChanged: canManage
                          ? (id) => setState(() {
                              _selectedVoice = voices.firstWhere(
                                (v) => v.id == id,
                              );
                            })
                          : null,
                      items: [
                        for (final v in voices)
                          DropdownMenuItem<String>(
                            value: v.id,
                            child: Text(
                              v.builtIn ? '${v.name}  ·  built-in' : v.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected != null && !selected.builtIn)
                    IconButton(
                      tooltip: 'Delete voice',
                      onPressed: canManage
                          ? () => _deleteVoice(selected)
                          : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelReady = _tts.isReady;
    final hasReference = _selectedVoice != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Guten-Speak — Voice Clone Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(_status),
                    if (_downloadFraction != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _downloadFraction),
                      Text('${(_downloadFraction! * 100).toStringAsFixed(0)}%'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _prepareModel,
              icon: const Icon(Icons.download),
              label: Text(modelReady ? 'Model ready' : '1. Prepare model'),
            ),
            const SizedBox(height: 8),
            _buildVoiceCard(context, modelReady),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Text to speak',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Steps: $_numSteps'),
                Expanded(
                  child: Slider(
                    value: _numSteps.toDouble(),
                    min: 2,
                    max: 32,
                    divisions: 30,
                    label: '$_numSteps',
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _numSteps = v.round()),
                  ),
                ),
              ],
            ),
            Text(
              'Higher steps = closer to your voice but slower.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                Text('Temp: ${_temperature.toStringAsFixed(2)}'),
                Expanded(
                  child: Slider(
                    value: _temperature,
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    label: _temperature.toStringAsFixed(2),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _temperature = v),
                  ),
                ),
              ],
            ),
            Text(
              'Lower temperature = more faithful to your voice, less random.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (!modelReady || !hasReference || _busy)
                  ? null
                  : _speak,
              icon: const Icon(Icons.record_voice_over),
              label: const Text('3. Speak'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last run',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Audio: ${_lastResult!.audioSeconds.toStringAsFixed(2)} s '
                        '@ ${_lastResult!.sampleRate} Hz',
                      ),
                      Text('Generation: ${_lastResult!.generateMillis} ms'),
                      Text(
                        'Real-time factor: '
                        '${_lastResult!.realTimeFactor.toStringAsFixed(2)}x '
                        '(< 1.0 = faster than real time)',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
