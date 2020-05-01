import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:ufmp/data/musicCatalog.dart';
import 'package:ufmp/service/audioPlayerTask.dart';

import 'catalogList.dart';
import 'miniPlayer.dart';

// Top Level Function for background audio playback.
backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

/// Fetch music catalog data.
Future<List<MusicCatalog>> fetchMusicCatalog() async {
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
    // If the server did return a 200 OK response,
    // then parse the JSON.
    final data = response.data['music'] as List<dynamic>;
    final List<MusicCatalog> result =
        data.map((model) => MusicCatalog.fromJson(model)).toList();
    return result;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load music catalog');
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<List<MusicCatalog>> futureCatalog;

  @override
  void initState() {
    super.initState();
    futureCatalog = fetchMusicCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<MusicCatalog>>(
        future: futureCatalog,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.separated(
              itemCount: snapshot.data.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                return CatalogList(snapshot.data, index);
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text("${snapshot.error}"));
          }

          // By default, show a loading spinner.
          return Center(child: CircularProgressIndicator());
        },
      ),
      bottomNavigationBar: MiniPlayer(),
    );
  }
}
