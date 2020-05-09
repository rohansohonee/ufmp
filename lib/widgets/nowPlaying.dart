import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:ufmp/utils/parseDuration.dart';
import 'package:rxdart/rxdart.dart';

class NowPlaying extends StatefulWidget {
  @override
  _NowPlayingState createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double> _dragPositionSubject =
      BehaviorSubject.seeded(null);

  StreamSubscription periodicSubscription, playbackStateSubscription;

  @override
  void initState() {
    super.initState();

    periodicSubscription = Stream.periodic(Duration(seconds: 1)).listen((_) {
      _dragPositionSubject.add(
        AudioService.playbackState.currentPosition.toDouble(),
      );
    });

    playbackStateSubscription = AudioService.playbackStateStream
        .where((state) => state != null)
        .listen((state) {
      if (state.basicState == BasicPlaybackState.playing)
        periodicSubscription.resume();
      else {
        if (!periodicSubscription.isPaused) {
          periodicSubscription.pause();
        }
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
              return nowPlayingScreen(snapshot.data);
            }
            return Center(child: Text('Not Playing: Go back to home page.'));
          },
        ),
      ),
    );
  }

  Widget nowPlayingScreen(MediaItem mediaItem) {
    return ListView(
      children: <Widget>[
        CachedNetworkImage(imageUrl: mediaItem.artUri),
        // Seek Bar
        Stack(
          children: <Widget>[
            bufferedIndicator(mediaItem?.duration?.toDouble()),
            positionIndicator(mediaItem),
          ],
        ),
        SizedBox(height: 10.0),
        musicDetails(mediaItem),
        SizedBox(height: 10.0),
        playControls(),
      ],
    );
  }

  Widget musicDetails(MediaItem mediaItem) {
    return Column(
      children: <Widget>[
        Text(mediaItem.title),
        Text('${mediaItem.album} • ${mediaItem.artist}'),
      ],
    );
  }

  Widget positionIndicator(MediaItem mediaItem) {
    return StreamBuilder<double>(
      stream: _dragPositionSubject.stream,
      builder: (context, snapshot) {
        double position = snapshot.data ?? 0.0;
        double duration = mediaItem?.duration?.toDouble();
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
                  AudioService.seekTo(value.toInt());
                  periodicSubscription.resume();
                },
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(prettyDuration(position ~/ 1000)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Text(prettyDuration(duration ~/ 1000)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget bufferedIndicator(double duration) {
    return StreamBuilder(
      stream: AudioService.customEventStream,
      builder: (context, snapshot) {
        return LinearPercentIndicator(
          percent: !snapshot.hasData
              ? 0.0
              : (snapshot.data.toDouble() / duration) >= 0.9
                  ? 1.0
                  : snapshot.data.toDouble() / duration,
          linearStrokeCap: LinearStrokeCap.butt,
          lineHeight: 2.0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        );
      },
    );
  }

  Widget playControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          icon: Icon(Icons.skip_previous),
          onPressed: () => AudioService.skipToPrevious(),
        ),
        StreamBuilder<PlaybackState>(
          stream: AudioService.playbackStateStream,
          builder: (context, snapshot) {
            final basicState = snapshot.data?.basicState;
            return IconButton(
              iconSize: 60.0,
              icon: Icon(
                basicState == BasicPlaybackState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              onPressed: () => basicState == BasicPlaybackState.playing
                  ? AudioService.pause()
                  : AudioService.play(),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_next),
          onPressed: () => AudioService.skipToNext(),
        ),
      ],
    );
  }
}
