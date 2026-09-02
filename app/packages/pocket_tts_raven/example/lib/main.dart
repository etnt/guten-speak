import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:pocket_tts_raven/pocket_tts_raven.dart' as raven;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'not started';

  @override
  void initState() {
    super.initState();
    _runSmoke();
  }

  void _runSmoke() {
    // Milestone smoke test: load the native library and confirm the ptt_* C API
    // symbols resolve. This proves libpocket_tts_raven.so built and linked
    // (ONNX Runtime + SentencePiece) and is loadable on-device.
    try {
      final DynamicLibrary lib = raven.openPocketTtsRavenLibrary();
      final bool hasCreate = lib.providesSymbol('ptt_create');
      final bool hasStreamStart = lib.providesSymbol('ptt_stream_start');
      final bool hasStreamRead = lib.providesSymbol('ptt_stream_read');
      final bool hasDestroy = lib.providesSymbol('ptt_destroy');
      final bool ok =
          hasCreate && hasStreamStart && hasStreamRead && hasDestroy;
      final String msg = ok
          ? 'OK — libpocket_tts_raven.so loaded; ptt_* symbols resolved'
          : 'library loaded but missing symbols '
                '(create=$hasCreate start=$hasStreamStart '
                'read=$hasStreamRead destroy=$hasDestroy)';
      debugPrint('RAVEN_SMOKE: $msg');
      setState(() {
        _status = msg;
      });
    } catch (e) {
      debugPrint('RAVEN_SMOKE: FAILED to load native library: $e');
      setState(() {
        _status = 'FAILED to load native library: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 22);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Pocket TTS Raven — smoke')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(_status, style: textStyle, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
