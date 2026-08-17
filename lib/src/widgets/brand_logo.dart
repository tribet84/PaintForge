import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The PintaMinis mark.
///
/// Vector rather than a bitmap so one asset covers every size without
/// shipping five near-identical PNGs, and recoloured through the theme
/// instead of baked in: the artwork is a flat silhouette, which would
/// disappear against the dark theme's background if left black.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64, this.color});

  final double size;

  /// Defaults to the theme's primary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.asset(
      'assets/brand/logo.svg',
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: 'PintaMinis',
    );
  }
}
