import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:flutter/material.dart';
import 'package:ufmp/data/musicCatalog.dart';

class CatalogModel extends ChangeNotifier {
  /// Internal, private state of the catalog.
  final List<MusicCatalog> _items = [];

  /// An unmodifiable view of the items in the catalog.
  UnmodifiableListView<MusicCatalog> get items => UnmodifiableListView(_items);

  CatalogModel() {
    _fetchMusicCatalog();
  }

  /// Fetches the music catalog data.
  Future<void> _fetchMusicCatalog() async {
    // Using the music catalog provided by uamp sample.
    const catalogUrl = 'https://storage.googleapis.com/uamp/catalog.json';

    final dio = Dio();

    // Adding an interceptor to enable caching.
    dio.interceptors.add(
      DioCacheManager(
        CacheConfig(baseUrl: catalogUrl),
      ).interceptor,
    );

    final response = await dio.get(
      catalogUrl,
      options: buildCacheOptions(
        Duration(days: 7),
        options: (Options(contentType: 'application/json')),
      ),
    );

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response, then parse the JSON.
      final data = response.data['music'] as List<dynamic>;
      final List<MusicCatalog> result =
          data.map((model) => MusicCatalog.fromJson(model)).toList();
      addAll(result);
    } else {
      // If the server did not return a 200 OK response, then throw an
      // exception.
      throw Exception('Failed to load music catalog');
    }
  }

  /// Adds [item] to catalog.
  void add(MusicCatalog item) {
    _items.add(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  /// Adds [items] to catalog.
  void addAll(List<MusicCatalog> items) {
    _items.addAll(items);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  /// Removes all items from the catalog.
  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }
}
