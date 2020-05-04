import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ufmp/utils/parseDuration.dart';
import 'package:rxdart/rxdart.dart';

class NowPlaying extends StatelessWidget {
  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double> _dragPositionSubject =
      BehaviorSubject.seeded(null);
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
        StreamBuilder<PlaybackState>(
          stream: AudioService.playbackStateStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              final basicState = state?.basicState;
              if (basicState != BasicPlaybackState.none &&
                  basicState != BasicPlaybackState.stopped)
                return positionIndicator(mediaItem, state);
            }
            return Container();
          },
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

  // TODO: (BUG) Improve seek bar code (pull request is welcome)
  Widget positionIndicator(MediaItem mediaItem, PlaybackState state) {
    double seekPos;
    return StreamBuilder(
      stream: Rx.combineLatest2<double, double, double>(
          _dragPositionSubject.stream,
          Stream.periodic(Duration(milliseconds: 200)),
          (dragPosition, _) => dragPosition),
      builder: (context, snapshot) {
        double position = snapshot.data ?? state.currentPosition?.toDouble();
        double duration = mediaItem?.duration?.toDouble();
        return Column(
          children: [
            if (duration != null)
              Slider(
                min: 0.0,
                max: duration,
                value: seekPos ?? max(0.0, min(position, duration)),
                onChanged: (value) {
                  _dragPositionSubject.add(value);
                },
                onChangeEnd: (value) {
                  AudioService.seekTo(value.toInt());
                  seekPos = value;
                  _dragPositionSubject.add(null);
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

  Widget playControls() {
    return StreamBuilder<PlaybackState>(
      stream: AudioService.playbackStateStream,
      builder: (context, snapshot) {
        final basicState = snapshot.data?.basicState;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.skip_previous),
              onPressed: () => AudioService.skipToPrevious(),
            ),
            IconButton(
              iconSize: 60.0,
              icon: Icon(
                basicState == BasicPlaybackState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              onPressed: () => basicState == BasicPlaybackState.playing
                  ? AudioService.pause()
                  : AudioService.play(),
            ),
            IconButton(
              icon: Icon(Icons.skip_next),
              onPressed: () => AudioService.skipToNext(),
            ),
          ],
        );
      },
    );
  }
}
