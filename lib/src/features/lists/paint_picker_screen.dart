import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/paint.dart';
import '../../state/paint_lists_provider.dart';
import '../../widgets/paint_widgets.dart';

/// Catalog search where each row toggles membership in a paint list.
///
/// Changes are written straight through, so there is no save button and no
/// half-applied state if the user backs out mid-way.
class PaintPickerScreen extends StatefulWidget {
  const PaintPickerScreen({super.key, required this.listId});

  final String listId;

  @override
  State<PaintPickerScreen> createState() => _PaintPickerScreenState();
}

class _PaintPickerScreenState extends State<PaintPickerScreen> {
  final _searchController = TextEditingController();
  PaintBrand? _brandFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = context.read<CatalogRepository>();
    final lists = context.watch<PaintListsProvider>();
    final list = lists.byId(widget.listId);

    final results =
        catalog.search(_searchController.text, brand: _brandFilter);
    final brandNames = {
      for (final paint in catalog.paints) paint.brand: paint.brandName,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? l10n.listAddPaints),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.listPaintCount(list?.paintIds.length ?? 0),
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
                  final selected =
                      list?.paintIds.contains(paint.id) ?? false;
                  return CheckboxListTile(
                    value: selected,
                    secondary: PaintSwatch(paint: paint),
                    title: Text(paint.name),
                    subtitle: Text(
                      [
                        paint.brandName,
                        paint.range,
                        if (paint.code != null) paint.code!,
                      ].join(' · '),
                    ),
                    onChanged: (value) {
                      if (value ?? false) {
                        lists.addPaint(widget.listId, paint.id);
                      } else {
                        lists.removePaint(widget.listId, paint.id);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
