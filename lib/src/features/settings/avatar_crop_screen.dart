import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Square crop step between picking an avatar photo and uploading it.
///
/// Pops with the cropped bytes, or null if the user backs out. The square is
/// locked to 1:1 — the avatar renders in a circle, and letting the rectangle
/// drift would only teach users their framing gets distorted later.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();

  /// Cropping re-encodes the bitmap, which on web runs on the UI thread —
  /// the button locks while it happens so a double tap cannot start two.
  var _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).recipePhotoUnreadable),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.avatarCropTitle),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: Text(l10n.actionSave),
          ),
        ],
      ),
      body: Stack(
        children: [
          Crop(
            image: widget.imageBytes,
            controller: _controller,
            aspectRatio: 1,
            // Start generous: most people want most of the photo, and
            // shrinking a big square is easier than growing a tiny one.
            initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
              size: 0.8,
              aspectRatio: 1,
            ),
            baseColor: Theme.of(context).colorScheme.surface,
            maskColor: Colors.black.withValues(alpha: .55),
            onCropped: _onCropped,
            // Corner dots are the resize handles; the default build is
            // fine, but slightly larger targets help on touch screens.
            cornerDotBuilder: (size, alignment) =>
                const DotControl(color: Colors.white),
          ),
          if (_cropping)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
