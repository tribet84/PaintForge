import 'package:flutter/material.dart';

/// An author's face wherever their public work appears.
///
/// Falls back to the name's initial — never to a generic person icon, so two
/// authors without pictures still look like two different people.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 24,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    final url = photoUrl;
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A dead or rate-limited URL degrades to the initial, not to a hole.
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
