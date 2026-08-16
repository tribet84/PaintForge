import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/paint.dart';
import '../../widgets/paint_widgets.dart';

/// Catalog search that toggles paints in a local selection and returns the
/// final set via `pop`. Unlike the paint-list picker, nothing is persisted
/// here — the recipe editor owns the draft.
class RecipePaintPickerScreen extends StatefulWidget {
  const RecipePaintPickerScreen({
    super.key,
    required this.initialSelection,
    this.single = false,
  });

  final Set<String> initialSelection;

  /// When true, tapping a paint returns `{paintId}` immediately.
  final bool single;

  @override
  State<RecipePaintPickerScreen> createState() =>
      _RecipePaintPickerScreenState();
}

class _RecipePaintPickerScreenState extends State<RecipePaintPickerScreen> {
  final _searchController = TextEditingController();
  PaintBrand? _brandFilter;
  late final Set<String> _selection = Set.of(widget.initialSelection);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = context.read<CatalogRepository>();
    final results =
        catalog.search(_searchController.text, brand: _brandFilter);
    final brandNames = {
      for (final paint in catalog.paints) paint.brand: paint.brandName,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_selection);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.listAddPaints),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.listPaintCount(_selection.length),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    FilterChip(
                      label: Text(l10n.filterAllBrands),
                      selected: _brandFilter == null,
                      onSelected: (_) => setState(() => _brandFilter = null),
                    ),
                    for (final entry in brandNames.entries) ...[
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(entry.value),
                        selected: _brandFilter == entry.key,
                        onSelected: (_) => setState(
                          () => _brandFilter =
                              _brandFilter == entry.key ? null : entry.key,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final paint = results[index];
                    final subtitle = [
                      paint.brandName,
                      paint.range,
                      if (paint.code != null) paint.code!,
                    ].join(' · ');
                    if (widget.single) {
                      return ListTile(
                        leading: PaintSwatch(paint: paint),
                        title: Text(paint.name),
                        subtitle: Text(subtitle),
                        selected: _selection.contains(paint.id),
                        onTap: () =>
                            Navigator.of(context).pop({paint.id}),
                      );
                    }
                    return CheckboxListTile(
                      value: _selection.contains(paint.id),
                      secondary: PaintSwatch(paint: paint),
                      title: Text(paint.name),
                      subtitle: Text(subtitle),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selection.add(paint.id);
                        } else {
                          _selection.remove(paint.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
