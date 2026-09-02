import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/storage/domain/entities/storage_usage.dart';
import 'package:guten_speak/features/storage/presentation/screens/storage_screen.dart';

void main() {
  group('StorageUsage', () {
    const usage = StorageUsage(
      models: <ModelUsage>[
        ModelUsage(id: 'raven', label: 'Raven', installed: true, bytes: 400),
      ],
      perBookAudio: <BookAudioUsage>[
        BookAudioUsage(bookId: 1, title: 'A', bytes: 30),
        BookAudioUsage(bookId: 2, title: 'B', bytes: 70),
      ],
      voiceCount: 2,
      voicesBytes: 50,
    );

    test('audioBytes sums every book', () {
      expect(usage.audioBytes, 100);
    });

    test('modelsBytes sums every engine model', () {
      expect(usage.modelsBytes, 400);
    });

    test('anyModelInstalled reflects installed models', () {
      expect(usage.anyModelInstalled, isTrue);
    });

    test('totalBytes sums models, audio and voices', () {
      expect(usage.totalBytes, 400 + 100 + 50);
    });

    test('empty audio yields zero totals', () {
      const empty = StorageUsage(
        models: <ModelUsage>[],
        perBookAudio: <BookAudioUsage>[],
        voiceCount: 0,
        voicesBytes: 0,
      );
      expect(empty.audioBytes, 0);
      expect(empty.modelsBytes, 0);
      expect(empty.anyModelInstalled, isFalse);
      expect(empty.totalBytes, 0);
    });
  });

  group('formatBytes', () {
    test('formats bytes below 1 KB as B', () {
      expect(formatBytes(512), '512 B');
    });

    test('formats kilobytes with no decimals', () {
      expect(formatBytes(2048), '2 KB');
    });

    test('formats megabytes with one decimal', () {
      expect(formatBytes(1024 * 1024 * 3 + 512 * 1024), '3.5 MB');
    });

    test('formats gigabytes with one decimal', () {
      expect(formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });
  });
}
