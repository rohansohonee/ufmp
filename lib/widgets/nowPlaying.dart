import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:ufmp/utils/parseDuration.dart';

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
            positionIndicator(mediaItem),
          ],
        ),
        SizedBox(height: 5.0),
        musicDetails(mediaItem),
        SizedBox(height: 5.0),
        playControls(),
      ],
    );
  }

  Widget musicDetails(MediaItem mediaItem) {
    return Column(
      children: <Widget>[
        Text(
          mediaItem.title,
          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        ),
        Text('${mediaItem.album} • ${mediaItem.artist}'),
      ],
    );
  }

  Widget positionIndicator(MediaItem mediaItem) {
    return StreamBuilder<double>(
      stream: _dragPositionSubject.stream,
      builder: (context, snapshot) {
        double position = snapshot.data ?? 0.0;
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
            final playing = snapshot.data?.playing ?? false;
            return IconButton(
              iconSize: 60.0,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () =>
                  playing ? AudioService.pause() : AudioService.play(),
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
