import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/paint.dart' as catalog;
import '../../widgets/paint_widgets.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  catalog.PaintBrand? _brandFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<CatalogRepository>();
    final results =
        repository.search(_searchController.text, brand: _brandFilter);
    final brandNames = {
      for (final paint in repository.paints) paint.brand: paint.brandName,
    };

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.resultsCount(results.length),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) =>
                  PaintTile(paint: results[index]),
            ),
          ),
        ],
      ),
    );
  }
}
