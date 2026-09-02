import 'dart:ffi';
import 'dart:io';

import 'pocket_tts_raven_bindings_generated.dart';

export 'pocket_tts_raven_bindings_generated.dart';

const String _libName = 'pocket_tts_raven';

/// Opens the native Pocket TTS Raven shared library for the current platform.
///
/// On Android the library is packaged as `libpocket_tts_raven.so`. This plugin
/// currently ships native binaries for Android arm64 only.
DynamicLibrary openPocketTtsRavenLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}

/// Lazily-opened default library handle.
final DynamicLibrary _dylib = openPocketTtsRavenLibrary();

/// Bindings to the native `ptt_*` C API, backed by the default library handle.
///
/// Native calls here are blocking; heavy calls (create, warmup, stream reads)
/// must be driven from a dedicated isolate, not the UI isolate.
final PocketTtsRavenBindings bindings = PocketTtsRavenBindings(_dylib);
