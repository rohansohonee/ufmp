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
  final _audioPlayer = AudioPlayer();
  int _queueIndex = -1;
  static int clickDelay = 0;
  List<MediaItem> _queue = <MediaItem>[];
  final _completer = Completer();
  bool _playing = false;
  bool _interrupted = false;

  bool get hasNext => _queueIndex + 1 < _queue.length;

  bool get hasPrevious => _queueIndex > 0;

  MediaItem get _mediaItem => _queue[_queueIndex];

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // Audio playback event listener.
    var playerEventSubscription =
        _audioPlayer.playbackEventStream.listen((event) {
      final bufferingState =
          event.buffering ? AudioProcessingState.buffering : null;
      switch (event.state) {
        case AudioPlaybackState.paused:
        case AudioPlaybackState.playing:
          _setState(
            state: bufferingState ?? AudioProcessingState.ready,
            position: event.position,
            bufferedPosition: event.bufferedPosition,
          );
          break;
        case AudioPlaybackState.completed:
          _handlePlaybackCompleted();
          break;
        default:
          break;
      }
    });

    await _completer.future;

    // Clean up resources
    _queue = null;
    playerEventSubscription.cancel();
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
    if (AudioServiceBackground.state.playing)
      onPause();
    else
      onPlay();
  }

  @override
  void onPlay() {
    _playing = true;
    _audioPlayer.play();
  }

  @override
  void onPause() {
    if (_audioPlayer.playbackState == AudioPlaybackState.connecting ||
        _audioPlayer.playbackState == AudioPlaybackState.playing) {
      _playing = false;
      _audioPlayer.pause();
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
          ? AudioProcessingState.skippingToPrevious
          : AudioProcessingState.skippingToNext,
    );

    await _audioPlayer.setUrl(_mediaItem.extras['source']);
    AudioServiceBackground.setMediaItem(_mediaItem);
    onPlay();
  }

  @override
  void onSeekTo(Duration position) {
    _audioPlayer.seek(position);
    // Broadcast that we're seeking.
    _setState(
      state: AudioServiceBackground.state.processingState,
      position: position,
    );
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
    if (_playing) await _audioPlayer.stop();
    _queueIndex = _queue.indexWhere((test) => test.id == mediaId);
    await _audioPlayer.setUrl(_mediaItem.extras['source']);
    AudioServiceBackground.setMediaItem(_mediaItem);
    onPlay();
  }

  @override
  Future<void> onStop() async {
    await _audioPlayer.stop();
    // Broadcast that we've stopped.
    await AudioServiceBackground.setState(
      controls: [],
      processingState: AudioProcessingState.stopped,
      playing: false,
    );
    _completer.complete();
  }

  @override
  Future<void> onUpdateQueue(List<MediaItem> mediaItems) async {
    _queue = mediaItems;
    AudioServiceBackground.setQueue(_queue);
  }

  /* Manage Audio Focus */
  @override
  void onAudioBecomingNoisy() {
    onPause();
  }

  @override
  void onAudioFocusGained(AudioInterruption interruption) {
    switch (interruption) {
      case AudioInterruption.temporaryPause:
        if (!_playing && _interrupted) onPlay();
        break;
      case AudioInterruption.temporaryDuck:
        _audioPlayer.setVolume(1.0);
        break;
      default:
        break;
    }
    _interrupted = false;
  }

  @override
  void onAudioFocusLost(AudioInterruption interruption) {
    if (_playing) _interrupted = true;
    switch (interruption) {
      case AudioInterruption.pause:
      case AudioInterruption.temporaryPause:
      case AudioInterruption.unknownPause:
        onPause();
        break;
      case AudioInterruption.temporaryDuck:
        _audioPlayer.setVolume(0.5);
        break;
    }
  }

  /// Helper method to set background state with ease.
  void _setState(
      {@required AudioProcessingState state,
      Duration position,
      Duration bufferedPosition}) {
    if (position == null) {
      position = _audioPlayer.playbackEvent.position;
    }
    AudioServiceBackground.setState(
      controls: controls,
      systemActions: [MediaAction.seekTo],
      processingState: state,
      playing: _playing,
      position: position,
      bufferedPosition: bufferedPosition ?? position,
    );
  }

  List<MediaControl> get controls => [
        skipToPreviousControl,
        // switch the controls to play/pause.
        _playing ? pauseControl : playControl,
        skipToNextControl
      ];
}
