import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Waiting indicator that breathes the app's own mark.
///
/// Used where a wait is blocking and there is room to show it — a full
/// screen, a modal — not inside buttons or image slots, where the logo's
/// detail turns to mush and a plain spinner reads better.
///
/// Nothing is painted for [delay] first. Most calls answer faster than a
/// person perceives a wait, and a loader that flashes up and vanishes reads
/// as a glitch rather than as progress; only a wait long enough to notice
/// gets an indicator.
class BrandLoader extends StatefulWidget {
  const BrandLoader({
    super.key,
    this.size = 72,
    this.label,
    this.delay = const Duration(milliseconds: 300),
  });

  final double size;

  /// Optional line under the mark, e.g. "Deleting your account".
  final String? label;

  /// How long to stay invisible before admitting there is a wait.
  final Duration delay;

  /// Marks the pulsing wrapper, so a test can assert the animation is
  /// actually skipped under reduce-motion without reaching into Flutter's
  /// internal widget types.
  static const pulseKey = Key('brand-loader-pulse');

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    if (widget.delay == Duration.zero) {
      _visible = true;
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10nLabel = widget.label;
    // Honour the platform's reduce-motion setting: a pulsing logo is
    // decoration, and for someone who asked for stillness it is worse than
    // no animation at all.
    final animate = !MediaQuery.disableAnimationsOf(context);

    final mark = animate
        ? AnimatedBuilder(
            key: BrandLoader.pulseKey,
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Opacity(
                opacity: 0.55 + 0.45 * t,
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              );
            },
            child: BrandLogo(size: widget.size),
          )
        : BrandLogo(size: widget.size);

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Semantics(
        // Screen readers get a plain "busy" signal; the pulsing artwork
        // means nothing to them.
        label: l10nLabel,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            if (l10nLabel != null) ...[
              const SizedBox(height: 16),
              Text(
                l10nLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
