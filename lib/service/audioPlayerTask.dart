import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  List<MediaItem> _queue = List<MediaItem>();
  final _completer = Completer();
  bool _playing = false;

  bool get hasNext => _queueIndex + 1 < _queue.length;

  bool get hasPrevious => _queueIndex > 0;

  MediaItem get _mediaItem => _queue[_queueIndex];

  @override
  Future<void> onStart() async {
    // Audio playback completed listener.
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
    await _audioPlayer.dispose();
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
    if (_audioPlayer.playbackState == AudioPlaybackState.connecting ||
        _audioPlayer.playbackState == AudioPlaybackState.playing) {
      _audioPlayer.pause();
      _playing = false;
      // Broadcast that we're paused.
      _setState(state: BasicPlaybackState.paused);
    }
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
    _setState(
      state: offset == -1
          ? BasicPlaybackState.skippingToPrevious
          : BasicPlaybackState.skippingToNext,
    );

    await _audioPlayer.setUrl(_mediaItem.extras['source']);
    AudioServiceBackground.setMediaItem(_mediaItem);
    onPlay();
  }

  @override
  void onSeekTo(int position) {
    _audioPlayer.seek(Duration(milliseconds: position));
  }

  @override
  void onClick(MediaButton button) {
    switch (button) {
      case MediaButton.media:
        // Implemented 'double tap to skip' feature for headset
        // using a click delay.
        clickDelay++;
        if (clickDelay == 1)
          Future.delayed(Duration(milliseconds: 250), () {
            if (clickDelay == 1) playPause();
            if (clickDelay == 2) onSkipToNext();
            clickDelay = 0;
          });

        break;
      case MediaButton.next:
        onSkipToNext();
        break;
      case MediaButton.previous:
        onSkipToPrevious();
        break;
      default:
    }
  }

  @override
  void onPlayFromMediaId(String mediaId) async {
    if (_playing) {
      await _audioPlayer.stop();
    }
    _queueIndex = _queue.indexWhere((test) => test.id == mediaId);
    AudioServiceBackground.setMediaItem(_mediaItem);
    await _audioPlayer.setUrl(_mediaItem.extras['source']);
    onPlay();
  }

  @override
  Future<void> onStop() async {
    await _audioPlayer.stop();
    _completer.complete();
  }

  @override
  void onAddQueueItem(MediaItem mediaItem) {
    _queue.add(mediaItem);
    AudioServiceBackground.setQueue(_queue);
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

  /// Helper method to set background state with ease.
  void _setState({@required BasicPlaybackState state, int position}) {
    if (position == null) {
      position = _audioPlayer.playbackEvent.position.inMilliseconds;
    }
    AudioServiceBackground.setState(
      controls: controls,
      systemActions: [MediaAction.seekTo],
      basicState: state,
      position: position,
    );
  }

  List<MediaControl> get controls => [
        skipToPreviousControl,
        // switch the controls to play/pause.
        _playing ? pauseControl : playControl,
        skipToNextControl
      ];
}
