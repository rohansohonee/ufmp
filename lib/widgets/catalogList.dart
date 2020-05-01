import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ufmp/data/musicCatalog.dart';
import 'package:ufmp/utils/mediaItemRaw.dart';
import 'package:ufmp/utils/parseDuration.dart';

import 'home.dart';

class CatalogList extends StatelessWidget {
  final List<MusicCatalog> data;
  final int index;
  const CatalogList(this.data, this.index);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem>(
      stream: AudioService.currentMediaItemStream,
      builder: (context, snapshot) {
        return ListTile(
          selected: snapshot.hasData
              ? (snapshot.data.id == data[index].id ? true : false)
              : false,
          leading: CachedNetworkImage(imageUrl: data[index].image),
          title: Text(data[index].title),
          subtitle: Text(data[index].artist),
          trailing: Text(prettyDuration(data[index].duration)),
          onTap: () => play(data[index].id, index),
        );
      },
    );
  }

  play(String id, int index) async {
    if (AudioService.running) {
      AudioService.playFromMediaId(id);
    } else {
      if (await AudioService.start(
        backgroundTaskEntrypoint: backgroundTaskEntrypoint,
        androidStopForegroundOnPause: true,
      )) {
        // convert music catalog to mediaitem data type.
        // Also make it raw so that message codecs can accept it.
        final queue = data.map((catalog) {
          return mediaItem2raw(MediaItem(
            id: catalog.id,
            album: catalog.album,
            title: catalog.title,
            artist: catalog.artist,
            duration: durationInMillis(catalog.duration),
            genre: catalog.genre,
            artUri: catalog.image,
            extras: {'index': index, 'source': catalog.source},
          ));
        }).toList();
        // Now we send our queue data to the audio player task along
        // with the index.
        AudioService.customAction(
          'audio_task',
          {'queue': queue, 'index': index},
        );
      }
    }
  }
}
