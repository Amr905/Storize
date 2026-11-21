import 'package:storize_instagram/page/page_driver.dart';

/// Counts how many WebView sessions page mode opened (T-015a F1, I2).
///
/// `InstagramPlatform` reads it around a page-mode call: a call that opened
/// no session (governor paused, no session stored, lease busy, gate off)
/// cost no page load and is not a `PAGE_MODE_USED`; a call that opened one is
/// a use, whatever its result.
final class PageOpenCounter {
  int _opened = 0;

  /// Sessions opened (or attempted) so far.
  int get opened => _opened;
}

/// A [PageDriver] that counts every `open` in [counter]. Counting happens at
/// the start of `open`, so a late or failing open still counts.
final class CountingPageDriver implements PageDriver {
  /// Wraps [inner].
  const CountingPageDriver(this.inner, this.counter);

  /// The real driver.
  final PageDriver inner;

  /// Where opens are counted.
  final PageOpenCounter counter;

  @override
  Future<PageSession> open(PageSessionConfig config) async {
    counter._opened++;
    return inner.open(config);
  }
}
