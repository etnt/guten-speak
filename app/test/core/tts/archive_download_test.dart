import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/archive_download.dart';

/// Host tests for the shared model-download utility that the Raven manager
/// delegates to. These exercise the parts that do NOT depend on
/// `path_provider` (extraction layout, fallback, resume, cancellation).
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('archive_download_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Builds a `.tar.bz2` at [path] whose entries are [files] (name -> bytes).
  Future<void> writeTarBz2(String path, Map<String, List<int>> files) async {
    final archive = Archive();
    files.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    final tarBytes = TarEncoder().encode(archive);
    final bz2 = BZip2Encoder().encode(tarBytes);
    await File(path).writeAsBytes(bz2, flush: true);
  }

  group('extractTarBz2', () {
    test('extracts a top-level model dir into the destination root', () async {
      final archivePath = '${tmp.path}/raven-int8-2026-01.tar.bz2';
      await writeTarBz2(archivePath, {
        'raven-int8-2026-01/flow_lm_main_int8.onnx': [1, 2, 3],
        'raven-int8-2026-01/tokenizer.model': [4, 5, 6, 7],
      });

      final dest = Directory('${tmp.path}/models')..createSync();
      await extractTarBz2(File(archivePath), dest);

      final modelDir = '${dest.path}/raven-int8-2026-01';
      expect(File('$modelDir/flow_lm_main_int8.onnx').existsSync(), isTrue);
      expect(File('$modelDir/tokenizer.model').existsSync(), isTrue);
      expect(File('$modelDir/tokenizer.model').lengthSync(), 4);
    });

    test('deletes the compressed archive after extraction', () async {
      final archivePath = '${tmp.path}/bundle.tar.bz2';
      await writeTarBz2(archivePath, {
        'bundle/a.bin': [9],
      });

      final dest = Directory('${tmp.path}/out')..createSync();
      await extractTarBz2(File(archivePath), dest);

      expect(File(archivePath).existsSync(), isFalse);
      expect(File('${dest.path}/bundle/a.bin').existsSync(), isTrue);
    });

    test('extracts when the archive matches the expected SHA-256', () async {
      final archivePath = '${tmp.path}/verified.tar.bz2';
      await writeTarBz2(archivePath, {
        'bundle/a.bin': [1, 2, 3],
      });
      final sha = sha256
          .convert(File(archivePath).readAsBytesSync())
          .toString();

      final dest = Directory('${tmp.path}/out')..createSync();
      await extractTarBz2(File(archivePath), dest, expectedSha256: sha);

      expect(File('${dest.path}/bundle/a.bin').existsSync(), isTrue);
    });

    test('rejects and deletes an archive with a mismatched SHA-256', () async {
      final archivePath = '${tmp.path}/tampered.tar.bz2';
      await writeTarBz2(archivePath, {
        'bundle/a.bin': [1, 2, 3],
      });

      final dest = Directory('${tmp.path}/out')..createSync();
      await expectLater(
        extractTarBz2(File(archivePath), dest, expectedSha256: 'deadbeef' * 8),
        throwsA(isA<ArchiveIntegrityException>()),
      );

      // Nothing extracted, and the bad archive is removed for a clean retry.
      expect(File(archivePath).existsSync(), isFalse);
      expect(File('${dest.path}/bundle/a.bin').existsSync(), isFalse);
    });

    test('refuses to extract a path-traversal entry', () async {
      final archivePath = '${tmp.path}/malicious.tar.bz2';
      await writeTarBz2(archivePath, {
        'bundle/ok.bin': [1],
        '../escape.bin': [2],
      });

      final dest = Directory('${tmp.path}/out')..createSync();
      await expectLater(
        extractTarBz2(File(archivePath), dest),
        throwsA(isA<ArchiveIntegrityException>()),
      );

      // The traversal target above the destination must never be created.
      expect(File('${tmp.path}/escape.bin').existsSync(), isFalse);
    });
  });

  group('downloadArchiveWithFallback', () {
    test('falls back to the next URL when the first fails', () async {
      final payload = List<int>.generate(2048, (i) => i % 256);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      server.listen((req) async {
        if (req.uri.path == '/good') {
          req.response.add(payload);
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });
      final base = 'http://${server.address.host}:${server.port}';

      final target = File('${tmp.path}/dl.bin');
      final statuses = <String>[];
      await downloadArchiveWithFallback(
        ['$base/missing', '$base/good'],
        target,
        onStatus: statuses.add,
      );

      expect(target.existsSync(), isTrue);
      expect(await target.readAsBytes(), payload);
      expect(statuses.any((s) => s.contains('trying another source')), isTrue);
    });

    test('throws ModelDownloadCancelled when cancelled mid-stream', () async {
      // A response large enough to stream in multiple chunks so the cancel flag
      // is polled before completion.
      final payload = List<int>.filled(1 << 20, 7);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      server.listen((req) async {
        req.response.add(payload);
        await req.response.close();
      });
      final base = 'http://${server.address.host}:${server.port}';

      final target = File('${tmp.path}/cancelled.bin');
      await expectLater(
        downloadArchiveWithFallback(
          ['$base/anything'],
          target,
          isCancelled: () => true,
        ),
        throwsA(isA<ModelDownloadCancelled>()),
      );

      // The finished file is never produced; a `.part` may remain for resume.
      expect(target.existsSync(), isFalse);
    });

    test('resumes an interrupted download from the .part file', () async {
      final payload = List<int>.generate(4096, (i) => (i * 31) % 256);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      server.listen((req) async {
        final range = req.headers.value(HttpHeaders.rangeHeader);
        if (range != null && range.startsWith('bytes=')) {
          final start = int.parse(
            range.substring('bytes='.length).split('-')[0],
          );
          req.response.statusCode = HttpStatus.partialContent;
          req.response.add(payload.sublist(start));
        } else {
          req.response.add(payload);
        }
        await req.response.close();
      });
      final base = 'http://${server.address.host}:${server.port}';

      // Pre-seed a partial download.
      final target = File('${tmp.path}/resume.bin');
      await File('${target.path}.part').writeAsBytes(payload.sublist(0, 1000));

      await downloadArchiveWithFallback([' $base/x'.trim()], target);

      expect(await target.readAsBytes(), payload);
    });
  });
}
