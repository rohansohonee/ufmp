import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'nowPlaying.dart';

class MiniPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem>(
      stream: AudioService.currentMediaItemStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            child: Container(
              color: Colors.blueGrey[300],
              height: 80,
              width: MediaQuery.of(context).size.width,
              child: _miniPlayer(snapshot.data),
            ),
            onTap: () {
              // Navigate to now playing page.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NowPlaying()),
              );
            },
          );
        }
        return Container(
          color: Colors.grey[300],
          height: 65,
          width: MediaQuery.of(context).size.width,
          child: ListTile(
            isThreeLine: true,
            leading: FlutterLogo(),
            title: Text('Not Playing'),
            subtitle: Text('Tap on a song from the list.'),
          ),
        );
      },
    );
  }

  Widget _miniPlayer(MediaItem mediaItem) {
    return ListTile(
      isThreeLine: true,
      leading: CachedNetworkImage(imageUrl: mediaItem.artUri),
      title: Text(
        mediaItem.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${mediaItem.album} • ${mediaItem.artist}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: StreamBuilder<PlaybackState>(
        stream: AudioService.playbackStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data?.basicState ?? BasicPlaybackState.stopped;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (state == BasicPlaybackState.playing)
                IconButton(icon: Icon(Icons.pause), onPressed: pause)
              else
                IconButton(icon: Icon(Icons.play_arrow), onPressed: play),
              if (state != BasicPlaybackState.stopped)
                IconButton(icon: Icon(Icons.skip_next), onPressed: skipNext),
            ],
          );
        },
      ),
    );
  }

  play() => AudioService.play();

  pause() => AudioService.pause();

  skipNext() => AudioService.skipToNext();
}
