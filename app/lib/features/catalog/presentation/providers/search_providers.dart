import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/book_summary.dart';
import 'catalog_providers.dart';

part 'search_providers.g.dart';

/// Holds the current search query text. The UI updates this on every keystroke;
/// debouncing happens in [searchResults].
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

/// Debounced search results for the current [SearchQuery].
///
/// Waits 400ms after the last keystroke before hitting the network. When the
/// query changes the provider is disposed, which cancels both the debounce and
/// any in-flight request.
@riverpod
Future<List<BookSummary>> searchResults(Ref ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const <BookSummary>[];

  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  // Debounce.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  if (cancelToken.isCancelled) return const <BookSummary>[];

  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.getBooks(search: query, cancelToken: cancelToken);
  return result.when(
    onSuccess: (response) => response.results,
    onFailure: (failure) => throw failure,
  );
}
