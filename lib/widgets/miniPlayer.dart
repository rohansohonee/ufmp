import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ufmp/model/catalog.dart';

import 'catalogList.dart';
import 'nowPlaying.dart';

class MiniPlayer extends StatefulWidget {
  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Future<SharedPreferences> sharedPreferences;
  StreamSubscription notificationClickSubscription;
  bool pageOpened = false;

  @override
  void initState() {
    super.initState();
    sharedPreferences = SharedPreferences.getInstance();
    notificationClickSubscription = AudioService.notificationClickEventStream
        .where((event) => event)
        .listen((event) {
      if (!pageOpened) _openNowPlaying();
    });
  }

  @override
  void dispose() {
    notificationClickSubscription?.cancel();
    super.dispose();
  }

  void _openNowPlaying() async {
    // Navigate to now playing page.
    pageOpened = true;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NowPlaying()),
    );
    pageOpened = false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem>(
      stream: AudioService.currentMediaItemStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _miniBar(mediaItem: snapshot.data);
        }
        return FutureBuilder<SharedPreferences>(
          future: sharedPreferences,
          builder: (context, prefSnapshot) {
            if (prefSnapshot.hasData) {
              final prefs = prefSnapshot.data;
              if (prefs.containsKey('id')) {
                final mediaItem = MediaItem(
                  id: prefs.getString('id'),
                  album: prefs.getString('album'),
                  title: prefs.getString('title'),
                  artist: prefs.getString('artist'),
                  duration: Duration(seconds: prefs.getInt('duration')),
                  genre: prefs.getString('genre'),
                  artUri: prefs.getString('artUri'),
                  extras: {'source': prefs.getString('source')},
                );
                return _miniBar(mediaItem: mediaItem, loadFromPrefs: prefs);
              }
            }
            return Container(
              color: Colors.grey[300],
              height: 65,
              width: MediaQuery.of(context).size.width,
              child: ListTile(
                isThreeLine: true,
                leading: FlutterLogo(size: 36),
                title: Text('Not Playing'),
                subtitle: Text('Tap on a song from the list.'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _miniBar({MediaItem mediaItem, SharedPreferences loadFromPrefs}) {
    return Material(
      color: Colors.blueGrey[300],
      child: InkWell(
        child: Container(
          height: 65,
          width: MediaQuery.of(context).size.width,
          child: _miniPlayer(mediaItem, loadFromPrefs),
        ),
        onTap: _openNowPlaying,
      ),
    );
  }

  Widget _miniPlayer(MediaItem mediaItem, SharedPreferences loadFromPrefs) {
    return Row(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.0,
          child: CachedNetworkImage(
            imageUrl: mediaItem.artUri,
            fit: BoxFit.fitHeight,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  mediaItem.title,
                  maxLines: 1,
                  style: TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${mediaItem.album} • ${mediaItem.artist}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<PlaybackState>(
          stream: AudioService.playbackStateStream,
          builder: (context, snapshot) {
            final state =
                snapshot.data?.processingState ?? AudioProcessingState.stopped;
            final playing = snapshot.data?.playing ?? false;
            return Row(
              children: <Widget>[
                // Play/pause button
                IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () =>
                      playing ? pause() : play(mediaItem, loadFromPrefs),
                ),
                // Skip next button
                if (state != AudioProcessingState.stopped)
                  IconButton(
                    icon: Icon(Icons.skip_next),
                    onPressed: skipNext,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  play(MediaItem mediaItem, SharedPreferences prefs) {
    if (!AudioService.running && prefs != null) {
      final items = Provider.of<CatalogModel>(context, listen: false).items;
      int index = items.indexWhere((test) => test.id == mediaItem.id);
      final position = Duration(seconds: prefs.getInt('position'));
      playAudioByIndex(context, index, position);
    } else
      AudioService.play();
  }

  pause() => AudioService.pause();

  skipNext() => AudioService.skipToNext();
}
