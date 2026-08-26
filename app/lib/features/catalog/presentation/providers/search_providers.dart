import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/book_summary.dart';
import 'catalog_providers.dart';

part 'search_providers.g.dart';

/// Holds the **submitted** search query. The text field updates this only when
/// the user presses the search/enter action, so typing does not hit the index.
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

/// Search results for the submitted [SearchQuery].
///
/// Runs against the local, offline catalog index — instant and independent of
/// the Gutendex API. Fires only when the submitted query changes.
@riverpod
Future<List<BookSummary>> searchResults(Ref ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const <BookSummary>[];

  final local = await ref.watch(localCatalogDataSourceProvider.future);
  return local.search(query);
}
