import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ufmp/utils/mediaItemRaw.dart';

final playControl = MediaControl(
  androidIcon: 'drawable/ic_action_play_arrow',
  label: 'Play',
  action: MediaAction.play,
);
final pauseControl = MediaControl(
  androidIcon: 'drawable/ic_action_pause',
  label: 'Pause',
  action: MediaAction.pause,
);
final skipToPreviousControl = MediaControl(
  androidIcon: 'drawable/ic_action_skip_previous',
  label: 'Skip Previous',
  action: MediaAction.skipToPrevious,
);
final skipToNextControl = MediaControl(
  androidIcon: 'drawable/ic_action_skip_next',
  label: 'Skip Next',
  action: MediaAction.skipToNext,
);

class AudioPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _queueIndex = -1;
  static int clickDelay = 0;
  List<MediaItem> _queue;
  final _completer = Completer();
  bool _playing;

  bool get hasNext => _queueIndex + 1 < _queue.length;

  bool get hasPrevious => _queueIndex > 0;

  MediaItem get mediaItem => _queue[_queueIndex];

  // Our own customStart function that receives the queue.
  Future<void> customStart() async {
    // Set the queue.
    AudioServiceBackground.setQueue(_queue);

    // Let us set the media item
    AudioServiceBackground.setMediaItem(mediaItem);

    // Now we set the source url and begin playback.
    await _audioPlayer.setUrl(mediaItem.extras['source']);
    onPlay();
  }

  @override
  Future<void> onStart() async {
    // Broadcast that we are playing.
    _playing = true;
    _setState(state: BasicPlaybackState.playing);

    var playerStateSubscription = _audioPlayer.playbackStateStream
        .where((state) => state == AudioPlaybackState.completed)
        .listen((state) {
      _handlePlaybackCompleted();
    });

    await _completer.future;
    // Broadcast that we've stopped.
    AudioServiceBackground.setState(
      controls: [],
      basicState: BasicPlaybackState.stopped,
    );

    // Clean up resources
    _queue = null;
    playerStateSubscription.cancel();
    _audioPlayer.dispose();
  }

  void _handlePlaybackCompleted() {
    if (hasNext) {
      onSkipToNext();
    } else {
      onStop();
    }
  }

  void playPause() {
    if (AudioServiceBackground.state.basicState == BasicPlaybackState.playing)
      onPause();
    else
      onPlay();
  }

  @override
  void onPlay() {
    _audioPlayer.play();
    _playing = true;
    // Broadcast that we're playing.
    _setState(state: BasicPlaybackState.playing);
  }

  @override
  void onPause() {
    _audioPlayer.pause();
    _playing = false;
    // Broadcast that we're paused.
    _setState(state: BasicPlaybackState.paused);
  }

  @override
  void onSkipToNext() => skip(1);

  @override
  void onSkipToPrevious() => skip(-1);

  Future<void> skip(int offset) async {
    final newIndex = _queueIndex + offset;
    if (!(newIndex >= 0 && newIndex < _queue.length)) return;
    if (_playing) {
      await _audioPlayer.stop();
    }
    _queueIndex = newIndex;
    // Broadcast that we're skipping.
    if (offset == -1)
      _setState(state: BasicPlaybackState.skippingToPrevious);
    else
      _setState(state: BasicPlaybackState.skippingToNext);

    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.extras['source']);
    onPlay();
  }

  @override
  void onSeekTo(int position) {
    _audioPlayer.seek(Duration(milliseconds: position));
  }

  @override
  void onClick(MediaButton button) {
    // Implemented 'double tap to skip' feature for headset
    // using a click delay.
    if (MediaButton.media == button) {
      clickDelay++;
      if (clickDelay == 1)
        Future.delayed(Duration(milliseconds: 250), () {
          if (clickDelay == 1) playPause();
          if (clickDelay == 2) onSkipToNext();
          clickDelay = 0;
        });
    }
    if (MediaButton.next == button) onSkipToNext();
    if (MediaButton.previous == button) onSkipToPrevious();
  }

  @override
  void onPlayFromMediaId(String mediaId) async {
    if (_playing) {
      await _audioPlayer.stop();
    }
    _queueIndex = _queue.indexWhere((test) => test.id == mediaId);
    AudioServiceBackground.setMediaItem(mediaItem);
    await _audioPlayer.setUrl(mediaItem.extras['source']);
    onPlay();
  }

  @override
  void onStop() {
    _audioPlayer.stop();
    _completer.complete();
  }

  /* Manage Audio Focus */
  @override
  void onAudioBecomingNoisy() {
    onPause();
  }

  @override
  void onAudioFocusGained() {
    _audioPlayer.setVolume(1.0);
    onPlay();
  }

  @override
  void onAudioFocusLost() {
    onPause();
  }

  @override
  void onAudioFocusLostTransient() {
    onPause();
  }

  @override
  void onAudioFocusLostTransientCanDuck() {
    onPause();
    _audioPlayer.setVolume(0.5);
  }

  /* You can implement your own custom actions here. */
  @override
  void onCustomAction(String name, arguments) {
    switch (name) {
      case 'audio_task':
        final result = arguments as Map<dynamic, dynamic>;
        final list = result['queue'] as List<dynamic>;
        // set the queue and queueIndex resp.
        _queue = list.map((item) => raw2mediaItem(item)).toList();
        _queueIndex = result['index'];
        // invoke our custom start.
        customStart();
        break;
      default:
    }
  }

  /// Helper method to set background state with ease.
  void _setState({@required BasicPlaybackState state, int position}) {
    if (position == null) {
      position = _audioPlayer.playbackEvent.position.inMilliseconds;
    }
    AudioServiceBackground.setState(
      controls: getControls(),
      systemActions: [MediaAction.seekTo],
      basicState: state,
      position: position,
    );
  }

  List<MediaControl> getControls() {
    return [
      skipToPreviousControl,
      // switch the controls to play/pause.
      _playing ? pauseControl : playControl,
      skipToNextControl
    ];
  }
}
