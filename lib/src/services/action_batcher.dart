import 'dart:async';

/// Coalesces rapid repeated actions into one summary event instead of
/// firing once per action.
///
/// Tapping "bought it" on ten different paints in quick succession should not
/// queue ten separate notifications playing one after another — it should
/// read as one event: "10 paints marked as bought". [record] restarts the
/// countdown on every call; [onSettled] fires once, [debounce] after the last
/// recorded action, with the total count and the most recent value.
class ActionBatcher<T> {
  ActionBatcher({
    required void Function(int count, T last) onSettled,
    this.debounce = const Duration(milliseconds: 900),
  }) : _onSettled = onSettled;

  final void Function(int count, T last) _onSettled;
  final Duration debounce;

  Timer? _timer;
  int _count = 0;
  T? _last;

  void record(T value) {
    _count++;
    _last = value;
    _timer?.cancel();
    _timer = Timer(debounce, _settle);
  }

  void _settle() {
    final count = _count;
    final last = _last as T;
    _count = 0;
    _last = null;
    _onSettled(count, last);
  }

  /// Drops any pending batch without delivering it — for when another,
  /// broader action (e.g. "mark everything") already covers what this batch
  /// would have reported, so its eventual summary would just be a redundant,
  /// possibly-stale second notification.
  void discard() {
    _timer?.cancel();
    _timer = null;
    _count = 0;
    _last = null;
  }

  /// Call when the owner (e.g. a State) is disposed, so the timer never
  /// fires against a gone widget.
  void dispose() => discard();
}
