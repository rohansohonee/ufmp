import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ufmp/model/catalog.dart';
import 'package:ufmp/utils/parseDuration.dart';

import 'catalogList.dart';

class NowPlaying extends StatefulWidget {
  @override
  _NowPlayingState createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double> _dragPositionSubject =
      BehaviorSubject.seeded(null);

  StreamSubscription periodicSubscription, playbackStateSubscription;
  Future<SharedPreferences> sharedPreferences;

  @override
  void initState() {
    super.initState();
    sharedPreferences = SharedPreferences.getInstance();

    periodicSubscription = Stream.periodic(Duration(seconds: 1)).listen((_) {
      _dragPositionSubject.add(
        AudioService.playbackState.currentPosition.inMilliseconds.toDouble(),
      );
    });

    playbackStateSubscription = AudioService.playbackStateStream
        .where((state) => state != null)
        .listen((state) {
      if (state.playing) {
        periodicSubscription.resume();
      } else if (!periodicSubscription.isPaused) {
        periodicSubscription.pause();
      }
    });
  }

  @override
  void dispose() {
    periodicSubscription?.cancel();
    playbackStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('Now Playing')),
      body: Center(
        child: StreamBuilder<MediaItem>(
          stream: AudioService.currentMediaItemStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return nowPlayingScreen(mediaItem: snapshot.data);
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
                    return nowPlayingScreen(
                        mediaItem: mediaItem, loadFromPrefs: prefs);
                  }
                }
                return Center(
                  child: Text('Not Playing: Go back to home page.'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget nowPlayingScreen(
      {MediaItem mediaItem, SharedPreferences loadFromPrefs}) {
    return ListView(
      children: <Widget>[
        SizedBox(height: 10.0),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 20.0),
          elevation: 5.0,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CachedNetworkImage(
              imageUrl: mediaItem.artUri,
              fit: BoxFit.fitHeight,
            ),
          ),
        ),
        // Seek Bar
        Stack(
          children: <Widget>[
            bufferedIndicator(mediaItem?.duration?.inMilliseconds?.toDouble()),
            positionIndicator(mediaItem, loadFromPrefs),
          ],
        ),
        SizedBox(height: 5.0),
        musicDetails(mediaItem),
        SizedBox(height: 5.0),
        playControls(mediaItem, loadFromPrefs),
      ],
    );
  }

  Widget musicDetails(MediaItem mediaItem) {
    return Column(
      children: <Widget>[
        Text(
          mediaItem.title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10.0),
        Text('${mediaItem.album} • ${mediaItem.artist}'),
      ],
    );
  }

  Widget positionIndicator(MediaItem mediaItem, SharedPreferences prefs) {
    return StreamBuilder<double>(
      stream: _dragPositionSubject.stream,
      builder: (context, snapshot) {
        double position = AudioService.running
            ? snapshot.data ?? 0.0
            : (prefs != null && prefs.containsKey('position'))
                ? Duration(seconds: prefs.getInt('position'))
                    .inMilliseconds
                    .toDouble()
                : 0.0;
        double duration = mediaItem?.duration?.inMilliseconds?.toDouble();
        return Column(
          children: [
            if (duration != null)
              Slider(
                min: 0.0,
                max: duration,
                value: max(0.0, min(position, duration)),
                onChangeStart: (_) {
                  if (!periodicSubscription.isPaused)
                    periodicSubscription.pause();
                },
                onChanged: (value) => _dragPositionSubject.add(value),
                onChangeEnd: (value) {
                  AudioService.seekTo(Duration(milliseconds: value.toInt()));
                  periodicSubscription.resume();
                },
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    prettyDuration(Duration(milliseconds: position.toInt())),
                  ),
                ),
                if (duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Text(prettyDuration(mediaItem.duration)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget bufferedIndicator(double duration) {
    return StreamBuilder<PlaybackState>(
      stream: AudioService.playbackStateStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final bufferedPosition =
              snapshot.data.bufferedPosition.inMilliseconds.toDouble();

          return LinearPercentIndicator(
            percent: max(0.0, min(bufferedPosition / duration, 1.0)),
            linearStrokeCap: LinearStrokeCap.butt,
            lineHeight: 2.0,
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
          );
        }
        return Container();
      },
    );
  }

  Widget playControls(MediaItem mediaItem, SharedPreferences loadFromPrefs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        if (AudioService.running)
          IconButton(
            icon: Icon(Icons.skip_previous),
            onPressed: () => AudioService.skipToPrevious(),
          ),
        StreamBuilder<PlaybackState>(
          stream: AudioService.playbackStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return IconButton(
              iconSize: 60.0,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => playing
                  ? AudioService.pause()
                  : play(mediaItem, loadFromPrefs),
            );
          },
        ),
        if (AudioService.running)
          IconButton(
            icon: Icon(Icons.skip_next),
            onPressed: () => AudioService.skipToNext(),
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
}
