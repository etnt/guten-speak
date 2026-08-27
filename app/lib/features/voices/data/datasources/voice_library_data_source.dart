import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/voice.dart';

/// Stores and names imported voice samples so they can be reused without
/// re-importing. User voices live under `<appSupport>/voices/` with a small
/// `index.json` mapping ids → names; the built-in samples are materialized from
/// bundled assets at load time and are not persisted to the index.
///
/// Ported from the Guten-Speak PoC's `VoiceLibrary`.
class VoiceLibrary {
  Directory? _dir;
  final List<Voice> _builtIns = <Voice>[];
  final List<Voice> _user = <Voice>[];

  /// Bundled sample voices shipped as Flutter assets. Materialized to disk on
  /// load so sherpa-onnx (which reads from a file path) can use them.
  static const List<({String id, String name, String asset, String file})>
  _builtInAssets = <({String id, String name, String asset, String file})>[
    (
      id: '__builtin_reginald__',
      name: 'Reginald Ashworth (male)',
      asset: 'assets/voices/reginald-ashworth.wav',
      file: 'reginald-ashworth.wav',
    ),
    (
      id: '__builtin_deja__',
      name: 'Deja Thoris (female)',
      asset: 'assets/voices/deja-thoris.wav',
      file: 'deja-thoris.wav',
    ),
  ];

  /// Built-in voices first, then user voices in insertion order.
  List<Voice> get voices => <Voice>[..._builtIns, ..._user];

  /// Materializes the bundled sample voices and loads the persisted user
  /// voices.
  Future<void> load() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/voices');
    await dir.create(recursive: true);
    _dir = dir;

    _builtIns
      ..clear()
      ..addAll(await _materializeBuiltIns(dir));

    _user.clear();
    final index = File('${dir.path}/index.json');
    if (index.existsSync()) {
      try {
        final raw = jsonDecode(await index.readAsString()) as List<dynamic>;
        for (final entry in raw) {
          final map = entry as Map<String, dynamic>;
          final file = File('${dir.path}/${map['file']}');
          if (file.existsSync()) {
            _user.add(
              Voice(
                id: map['id'] as String,
                name: map['name'] as String,
                wavPath: file.path,
              ),
            );
          }
        }
      } on FormatException {
        // Corrupt index — start fresh rather than crash.
        _user.clear();
      }
    }
  }

  Future<List<Voice>> _materializeBuiltIns(Directory dir) async {
    final result = <Voice>[];
    for (final b in _builtInAssets) {
      final target = File('${dir.path}/${b.file}');
      if (!target.existsSync()) {
        final data = await rootBundle.load(b.asset);
        await target.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      result.add(
        Voice(id: b.id, name: b.name, wavPath: target.path, builtIn: true),
      );
    }
    return result;
  }

  /// Imports [sourceWavPath] under [name], copying it into app storage.
  Future<Voice> add({
    required String name,
    required String sourceWavPath,
  }) async {
    final dir = _dir;
    if (dir == null) {
      throw StateError('VoiceLibrary.load() must be called before add().');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '$id.wav';
    await File(sourceWavPath).copy('${dir.path}/$fileName');
    final voice = Voice(id: id, name: name, wavPath: '${dir.path}/$fileName');
    _user.add(voice);
    await _save();
    return voice;
  }

  /// Deletes a user voice (built-in voices are ignored).
  Future<void> remove(String id) async {
    final dir = _dir;
    if (dir == null) return;
    final idx = _user.indexWhere((v) => v.id == id);
    if (idx < 0) return;
    final voice = _user[idx];
    final file = File(voice.wavPath);
    if (file.existsSync()) {
      await file.delete();
    }
    _user.removeAt(idx);
    await _save();
  }

  /// Total bytes of the imported (non-built-in) voice `.wav` files on disk.
  Future<int> userVoicesBytes() async {
    var total = 0;
    for (final voice in _user) {
      final file = File(voice.wavPath);
      if (file.existsSync()) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<void> _save() async {
    final dir = _dir;
    if (dir == null) return;
    final data = _user
        .map(
          (v) => <String, String>{
            'id': v.id,
            'name': v.name,
            'file': '${v.id}.wav',
          },
        )
        .toList();
    final index = File('${dir.path}/index.json');
    await index.writeAsString(jsonEncode(data), flush: true);
  }
}
