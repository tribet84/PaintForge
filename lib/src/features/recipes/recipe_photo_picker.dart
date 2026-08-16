import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/image_compressor.dart';

const _compressor = ImageCompressor();

/// Runs the decode/resize/encode off the UI thread. A camera photo is big
/// enough that doing this inline visibly freezes the app.
String _compressInIsolate(Uint8List bytes) =>
    _compressor.compressToBase64(bytes);

/// Lets the user pick a photo, compresses it ON THE DEVICE, and returns it
/// base64-encoded ready to store.
///
/// Returns null if the user backed out. Surfaces a message and returns null
/// if the image could not be stored, rather than saving something oversized.
Future<String?> pickAndCompressRecipePhoto(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final source = await _chooseSource(context);
  if (source == null) return null;

  final picker = ImagePicker();
  final XFile? picked;
  try {
    picked = await picker.pickImage(
      source: source,
      // A first, cheap cut before the bytes ever reach us — the plugin can
      // often ask the camera for a smaller image directly.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recipePhotoUnreadable)),
    );
    return null;
  }
  if (picked == null) return null;

  messenger.showSnackBar(
    SnackBar(content: Text(l10n.recipePhotoCompressing)),
  );

  try {
    final bytes = await picked.readAsBytes();
    // compute() spawns an isolate on mobile/desktop; on web it falls back to
    // running inline, which is unavoidable there.
    final encoded = kIsWeb
        ? _compressInIsolate(bytes)
        : await compute(_compressInIsolate, bytes);
    messenger.clearSnackBars();
    return encoded;
  } on PhotoCompressionException catch (error) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            switch (error.reason) {
              PhotoRejection.unreadable => l10n.recipePhotoUnreadable,
              PhotoRejection.stillTooLarge => l10n.recipePhotoTooLarge,
            },
          ),
        ),
      );
    return null;
  } catch (_) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.recipePhotoUnreadable)));
    return null;
  }
}

Future<ImageSource?> _chooseSource(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.recipePhotoFromCamera),
            onTap: () =>
                Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.recipePhotoFromGallery),
            onTap: () =>
                Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              l10n.recipePhotoHelp,
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}
