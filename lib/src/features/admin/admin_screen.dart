import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/admin_stats_repository.dart';
import '../../widgets/paint_widgets.dart';

/// Platform statistics, reachable only from the admin entry in Settings.
///
/// The screen is gated twice: Settings only shows the entry for allowlisted
/// admins (see admin_access.dart), and every query below is additionally
/// enforced by the `isPlatformAdmin()` allowlist in `firestore.rules` — a
/// non-admin who somehow pushed this route would only see the error state.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, AdminStatsRepository? repository})
      : _repository = repository;

  /// Injectable for tests; defaults to the Firestore implementation.
  final AdminStatsRepository? _repository;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminData {
  const _AdminData(this.stats, this.latestShared);

  final PlatformStats stats;
  final List<SharedRecipeSummary> latestShared;
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminStatsRepository _repository =
      widget._repository ?? FirestoreAdminStatsRepository();
  late Future<_AdminData> _future = _load();

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      _repository.loadStats(),
      _repository.latestShared(),
    ]);
    return _AdminData(
      results[0] as PlatformStats,
      results[1] as List<SharedRecipeSummary>,
    );
  }

  Future<void> _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
    // Swallowed here so RefreshIndicator settles; FutureBuilder still
    // receives the error and renders the error state.
    return future.then<void>((_) {}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTitle),
        actions: [
          IconButton(
            tooltip: l10n.adminRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_AdminData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (snapshot.hasError || data == null) {
              return EmptyState(
                icon: Icons.lock_outline,
                title: l10n.adminLoadErrorTitle,
                body: l10n.adminLoadErrorBody,
                action: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.adminRetry),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: _AdminBody(data: data),
            );
          },
        ),
      ),
    );
  }
}

class _AdminBody extends StatelessWidget {
  const _AdminBody({required this.data});

  final _AdminData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stats = data.stats;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.adminSectionTotals, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              icon: Icons.people_outline,
              value: stats.painters,
              label: l10n.adminStatPainters,
            ),
            _StatCard(
              icon: Icons.palette_outlined,
              value: stats.inventoryEntries,
              label: l10n.adminStatInventory,
            ),
            _StatCard(
              icon: Icons.checklist_outlined,
              value: stats.paintLists,
              label: l10n.adminStatLists,
            ),
            _StatCard(
              icon: Icons.menu_book_outlined,
              value: stats.recipes,
              label: l10n.adminStatRecipes,
            ),
            _StatCard(
              icon: Icons.public_outlined,
              value: stats.publishedRecipes,
              label: l10n.adminStatPublished,
            ),
            _StatCard(
              icon: Icons.link_outlined,
              value: stats.recipeLinks,
              label: l10n.adminStatLinks,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.adminSectionLatestShared,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (data.latestShared.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.adminNoSharedRecipes,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final recipe in data.latestShared)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(recipe.name),
              subtitle: Text(
                recipe.updatedAt == null
                    ? recipe.authorName
                    : '${recipe.authorName} · '
                        '${dateFormat.format(recipe.updatedAt!)}',
              ),
              trailing: Text(
                l10n.adminLinkCount(recipe.linkCount),
                style: theme.textTheme.labelMedium,
              ),
            ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text('$value', style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
