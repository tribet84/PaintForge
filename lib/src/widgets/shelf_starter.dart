import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../data/catalog_repository.dart';
import '../models/inventory_entry.dart';
import '../models/paint.dart';
import '../state/inventory_provider.dart';

/// First-run flow for stocking an empty shelf.
///
/// Exists because of a measured drop-off, not a hunch: of the first eight
/// community sign-ups, five left without marking a single paint. The default
/// catalogue asks three gestures per pot (tap → sheet → option), which is
/// fine for one paint and hopeless for the thirty a first session needs.
/// Here it is one tap per pot: pick your brand, tap everything you own, one
/// button writes the lot in a single batch.
class ShelfStarter extends StatefulWidget {
  const ShelfStarter({super.key, required this.onDone});

  /// Called when the user adds their selection or walks away — either way
  /// the regular catalogue takes over.
  final VoidCallback onDone;

  @override
  State<ShelfStarter> createState() => _ShelfStarterState();
}

class _ShelfStarterState extends State<ShelfStarter> {
  PaintBrand _brand = PaintBrand.citadel;
  final _selected = <String>{};

  Future<void> _addSelection() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();
    // One batched write for the whole selection — same discipline as the
    // bulk actions in the catalogue.
    await inventory.setStatusForAll(_selected.toList(), PaintStatus.inStock);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.paintsBulkApplied(_selected.length))),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalog = context.read<CatalogRepository>();
    final paints = catalog.search('', brand: _brand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            l10n.shelfStarterTitle,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.shelfStarterBody,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final brand in PaintBrand.values) ...[
                ChoiceChip(
                  label: Text(catalog.search('', brand: brand).first.brandName),
                  selected: _brand == brand,
                  onSelected: (_) => setState(() => _brand = brand),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisExtent: 108,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: paints.length,
            itemBuilder: (context, index) {
              final paint = paints[index];
              final selected = _selected.contains(paint.id);
              return _StarterCell(
                paint: paint,
                selected: selected,
                onTap: () => setState(() {
                  selected ? _selected.remove(paint.id) : _selected.add(paint.id);
                }),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _addSelection,
                  child: Text(l10n.shelfStarterAdd(_selected.length)),
                ),
                // Never a trap: the full catalogue is one tap away, and the
                // starter simply does not come back once dismissed.
                TextButton(
                  onPressed: widget.onDone,
                  child: Text(l10n.shelfStarterSkip),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StarterCell extends StatelessWidget {
  const _StarterCell({
    required this.paint,
    required this.selected,
    required this.onTap,
  });

  final Paint paint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? scheme.primaryContainer.withValues(alpha: .35) : null,
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: paint.color ?? scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant, width: 2),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.check,
                          size: 12, color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                paint.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
