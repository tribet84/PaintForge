import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/image_compressor.dart';

const _compressor = ImageCompressor();

/// Runs the decode/resize/encode off the UI thread. A camera photo is big
/// enough that doing this inline visibly freezes the app.
Uint8List _compressWith((ImageCompressor, Uint8List) args) =>
    args.$1.compress(args.$2);

/// Picks a photo and returns its bytes UNCOMPRESSED (beyond the plugin's own
/// 2048px ceiling). For flows that need the full frame before deciding what
/// to keep — the avatar cropper works on these, then compresses the crop.
Future<Uint8List?> pickPhotoBytes(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final source = await _chooseSource(context);
  if (source == null) return null;

  final XFile? picked;
  try {
    picked = await _pickImage(source);
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recipePhotoUnreadable)),
    );
    return null;
  }
  // Null without an exception is the user backing out of the picker —
  // silence is the only right response to a cancel.
  if (picked == null) return null;
  return picked.readAsBytes();
}

Future<XFile?> _pickImage(ImageSource source) {
  return ImagePicker().pickImage(
    source: source,
    // A first, cheap cut before the bytes ever reach us — the plugin can
    // often ask the camera for a smaller image directly.
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 90,
  );
}

/// Lets the user pick a photo and compresses it ON THE DEVICE, returning the
/// bytes ready to upload.
///
/// Deliberately does NOT upload: the recipe editor is a draft until the user
/// saves, so uploading here would leave an orphaned object in Storage every
/// time someone picked a photo and then backed out.
///
/// [compressor] defaults to the recipe-photo budget; callers with smaller
/// targets (the profile avatar) pass their own.
///
/// Returns null if the user cancelled, or if the image could not be
/// processed — with a message explaining which.
Future<Uint8List?> pickAndCompressRecipePhoto(
  BuildContext context, {
  ImageCompressor compressor = _compressor,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final source = await _chooseSource(context);
  if (source == null) return null;

  final XFile? picked;
  try {
    picked = await _pickImage(source);
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
    final compressed = kIsWeb
        ? _compressWith((compressor, bytes))
        : await compute(_compressWith, (compressor, bytes));
    messenger.clearSnackBars();
    return compressed;
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
