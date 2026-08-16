import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';

/// Which slice of the catalogue is on screen.
enum PaintScope { mine, all }

/// The single place paints live.
///
/// "Catalogue" and "My paints" used to be separate tabs, which forced the
/// user to decide WHERE to go for one task — find a paint. They were never
/// two things: one is the other with a filter applied, and the duplication
/// showed (both had grown the same brand filter). Merging them also frees a
/// navigation slot.
///
/// The scope defaults to Mine once the user owns anything, because that is
/// the smaller, more relevant list; an empty shelf opens on All, since Mine
/// would be a blank screen.
class PaintsScreen extends StatefulWidget {
  const PaintsScreen({super.key});

  @override
  State<PaintsScreen> createState() => _PaintsScreenState();
}

class _PaintsScreenState extends State<PaintsScreen> {
  final _searchController = TextEditingController();
  PaintBrand? _brandFilter;
  PaintScope? _scope;
  var _selecting = false;
  final _selection = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selection.clear();
    });
  }

  Future<void> _applyToSelection(PaintStatus? status) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();
    final ids = List.of(_selection);
    if (ids.isEmpty) return;

    for (final id in ids) {
      if (status == null) {
        await inventory.remove(id);
      } else {
        await inventory.setStatus(id, status);
      }
    }
    _exitSelection();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(l10n.paintsBulkApplied(ids.length))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = context.read<CatalogRepository>();
    final inventory = context.watch<InventoryProvider>();

    final owned = inventory.entries;
    // First build decides the default; after that the user is in charge.
    final scope = _scope ??
        (owned.isEmpty ? PaintScope.all : PaintScope.mine);

    var results = catalog.search(_searchController.text, brand: _brandFilter);
    if (scope == PaintScope.mine) {
      results = results.where((p) => owned.containsKey(p.id)).toList();
    }

    // Brand chips offer every brand in scope — filtering to a brand you own
    // nothing from would be a dead end.
    final brandNames = <PaintBrand, String>{
      for (final paint in scope == PaintScope.mine
          ? catalog.paints.where((p) => owned.containsKey(p.id))
          : catalog.paints)
        paint.brand: paint.brandName,
    };
    if (_brandFilter != null && !brandNames.containsKey(_brandFilter)) {
      _brandFilter = null;
    }

    return SafeArea(
      child: Column(
        children: [
          if (_selecting)
            _SelectionToolbar(
              count: _selection.length,
              onCancel: _exitSelection,
              onSelectAllVisible: () => setState(
                () => _selection.addAll(results.map((p) => p.id)),
              ),
              onApply: _applyToSelection,
            )
          else
            _FilterHeader(
              searchController: _searchController,
              scope: scope,
              mineCount: owned.length,
              brandNames: brandNames,
              brandFilter: _brandFilter,
              resultCount: results.length,
              onSearchChanged: () => setState(() {}),
              onScopeChanged: (value) => setState(() => _scope = value),
              onBrandChanged: (value) => setState(() => _brandFilter = value),
              onStartSelecting: () => setState(() => _selecting = true),
            ),
          Expanded(
            child: _PaintResults(
              results: results,
              ownedStatus: owned,
              scope: scope,
              selecting: _selecting,
              selection: _selection,
              onToggle: (id) => setState(
                () => _selection.contains(id)
                    ? _selection.remove(id)
                    : _selection.add(id),
              ),
              emptyMessage: scope == PaintScope.mine
                  ? (owned.isEmpty
                      ? l10n.inventoryEmptyBody
                      : l10n.paintsMineEmptyFiltered)
                  : l10n.paintsAllEmptyFiltered,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.searchController,
    required this.scope,
    required this.mineCount,
    required this.brandNames,
    required this.brandFilter,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onScopeChanged,
    required this.onBrandChanged,
    required this.onStartSelecting,
  });

  final TextEditingController searchController;
  final PaintScope scope;
  final int mineCount;
  final Map<PaintBrand, String> brandNames;
  final PaintBrand? brandFilter;
  final int resultCount;
  final VoidCallback onSearchChanged;
  final ValueChanged<PaintScope> onScopeChanged;
  final ValueChanged<PaintBrand?> onBrandChanged;
  final VoidCallback onStartSelecting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      },
                    ),
            ),
            onChanged: (_) => onSearchChanged(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SegmentedButton<PaintScope>(
            segments: [
              ButtonSegment(
                value: PaintScope.mine,
                label: Text('${l10n.paintsScopeMine} $mineCount'),
                icon: const Icon(Icons.palette_outlined, size: 18),
              ),
              ButtonSegment(
                value: PaintScope.all,
                label: Text(l10n.paintsScopeAll),
                icon: const Icon(Icons.grid_view, size: 18),
              ),
            ],
            selected: {scope},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onScopeChanged(s.first),
          ),
        ),
        if (brandNames.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                FilterChip(
                  label: Text(l10n.filterAllBrands),
                  selected: brandFilter == null,
                  onSelected: (_) => onBrandChanged(null),
                ),
                for (final entry in brandNames.entries) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(entry.value),
                    selected: brandFilter == entry.key,
                    onSelected: (_) => onBrandChanged(
                      brandFilter == entry.key ? null : entry.key,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.resultsCount(resultCount),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed: resultCount == 0 ? null : onStartSelecting,
                icon: const Icon(Icons.checklist, size: 18),
                label: Text(l10n.paintsSelect),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Replaces the filters while selecting, so the actions sit where the user is
/// already looking instead of behind a menu.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.count,
    required this.onCancel,
    required this.onSelectAllVisible,
    required this.onApply,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSelectAllVisible;
  final ValueChanged<PaintStatus?> onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = count > 0;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.paintsSelectionCancel,
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
              Expanded(
                child: Text(
                  l10n.paintsSelectionCount(count),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onSelectAllVisible,
                child: Text(l10n.paintsSelectAllVisible),
              ),
            ],
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              children: [
                // Short status words, not the full sentences used in the
                // single-paint sheet: four long labels do not fit a phone,
                // and the toolbar has already established that these apply
                // to the selection.
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l10n.statusInStock),
                  onPressed: enabled ? () => onApply(PaintStatus.inStock) : null,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.hourglass_bottom, size: 18),
                  label: Text(l10n.statusLow),
                  onPressed: enabled ? () => onApply(PaintStatus.low) : null,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(l10n.statusWishlist),
                  onPressed:
                      enabled ? () => onApply(PaintStatus.wishlist) : null,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.actionDelete),
                  onPressed: enabled ? () => onApply(null) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaintResults extends StatelessWidget {
  const _PaintResults({
    required this.results,
    required this.ownedStatus,
    required this.scope,
    required this.selecting,
    required this.selection,
    required this.onToggle,
    required this.emptyMessage,
  });

  final List<Paint> results;

  /// Current status per paint, so the Mine scope can hide the status that is
  /// implied and surface only the exceptions.
  final Map<String, InventoryEntry> ownedStatus;

  final PaintScope scope;
  final bool selecting;
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Mine is short enough to group by brand, which makes a shelf easy to
    // audit. All is 400+ rows, where headers would just add scrolling.
    if (scope == PaintScope.mine && !selecting) {
      final byBrand = <String, List<Paint>>{};
      for (final paint in results) {
        byBrand.putIfAbsent(paint.brandName, () => []).add(paint);
      }
      final brands = byBrand.keys.toList()..sort();
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final brand in brands) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Text(
                brand,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            for (final paint in byBrand[brand]!)
              _row(context, paint, showBrand: false),
          ],
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      itemBuilder: (context, index) => _row(context, results[index]),
    );
  }

  Widget _row(BuildContext context, Paint paint, {bool showBrand = true}) {
    if (!selecting) {
      // In Mine, everything is owned by definition — stamping "Owned" on
      // every row is noise that buries the rows that actually need action.
      final implied = scope == PaintScope.mine &&
          ownedStatus[paint.id]?.status == PaintStatus.inStock;
      return PaintTile(
        paint: paint,
        showBrand: showBrand,
        showStatus: !implied,
      );
    }
    final checked = selection.contains(paint.id);
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      value: checked,
      secondary: PaintSwatch(paint: paint, size: 36),
      title: Text(paint.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (showBrand) paint.brandName,
          paint.range,
          if (paint.code != null) paint.code!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onChanged: (_) => onToggle(paint.id),
    );
  }
}
