import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/voices/data/datasources/voice_library_data_source.dart';

void main() {
  group('ravenVoiceCachePaths', () {
    test('derives .emb and .kv from the wav stem (native contract)', () {
      final paths = ravenVoiceCachePaths(
        '/data/user/voices',
        '/data/user/voices/1725300000.wav',
      );
      expect(paths, <String>[
        '/data/user/voices/.cache/1725300000.emb',
        '/data/user/voices/.cache/1725300000.kv',
      ]);
    });

    test('uses only the filename stem, not the full path', () {
      final paths = ravenVoiceCachePaths(
        '/voices',
        '/some/other/dir/reginald-ashworth.wav',
      );
      expect(paths, <String>[
        '/voices/.cache/reginald-ashworth.emb',
        '/voices/.cache/reginald-ashworth.kv',
      ]);
    });

    test('handles a filename without an extension', () {
      final paths = ravenVoiceCachePaths('/voices', '/voices/novoiceext');
      expect(paths, <String>[
        '/voices/.cache/novoiceext.emb',
        '/voices/.cache/novoiceext.kv',
      ]);
    });

    test('returns nothing for an empty stem', () {
      expect(ravenVoiceCachePaths('/voices', '/voices/.wav'), isEmpty);
    });
  });
}
