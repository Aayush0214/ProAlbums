import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How far the Photos tab title has shrunk (0 = big, at the top of the
/// list, 1 = small). Published by the photo list while it scrolls and read by
/// the Photos app bar. Only changes in small steps, so the bar rebuilds a few
/// times, not on every scroll frame.
final photosTitleProgressProvider =
    NotifierProvider<PhotosTitleProgress, double>(PhotosTitleProgress.new);

class PhotosTitleProgress extends Notifier<double> {
  @override
  double build() => 0;

  /// [fromTop] = pixels scrolled away from the top of the list.
  void update(double fromTop) {
    final next = (fromTop / 56).clamp(0.0, 1.0);
    // 1/8 steps are smooth enough to the eye and cheap.
    final stepped = (next * 8).round() / 8;
    if (stepped != state) state = stepped;
  }
}
