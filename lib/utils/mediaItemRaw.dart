import 'package:audio_service/audio_service.dart';

Map mediaItem2raw(MediaItem mediaItem) => {
      'id': mediaItem.id,
      'album': mediaItem.album,
      'title': mediaItem.title,
      'artist': mediaItem.artist,
      'genre': mediaItem.genre,
      'duration': mediaItem.duration,
      'artUri': mediaItem.artUri,
      'playable': mediaItem.playable,
      'displayTitle': mediaItem.displayTitle,
      'displaySubtitle': mediaItem.displaySubtitle,
      'displayDescription': mediaItem.displayDescription,
      'extras': mediaItem.extras,
    };

MediaItem raw2mediaItem(Map raw) => MediaItem(
      id: raw['id'],
      album: raw['album'],
      title: raw['title'],
      artist: raw['artist'],
      genre: raw['genre'],
      duration: raw['duration'],
      artUri: raw['artUri'],
      displayTitle: raw['displayTitle'],
      displaySubtitle: raw['displaySubtitle'],
      displayDescription: raw['displayDescription'],
      extras: _raw2extras(raw['extras']),
    );

Map<String, dynamic> _raw2extras(Map raw) {
  if (raw == null) return null;
  final extras = <String, dynamic>{};
  for (var key in raw.keys) {
    extras[key as String] = raw[key];
  }
  return extras;
}
