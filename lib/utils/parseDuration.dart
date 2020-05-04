/// convert duration from seconds to milliseconds.
int durationInMillis(int duration) {
  return Duration(seconds: duration).inMilliseconds;
}

/// convert duration to human readable string.
String prettyDuration(int duration) {
  String seconds;
  final _duration = Duration(seconds: duration);
  final minutes = _duration.inMinutes.remainder(60);
  final sec = _duration.inSeconds.remainder(60);
  if (sec < 10)
    seconds = '0$sec';
  else
    seconds = '$sec';
  return '$minutes:$seconds';
}
