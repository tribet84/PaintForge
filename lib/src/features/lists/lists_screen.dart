import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../models/paint_list.dart';
import '../../state/inventory_provider.dart';
import '../../state/paint_lists_provider.dart';
import '../../widgets/paint_list_widgets.dart';
import '../../widgets/readiness_detail.dart';
import '../../widgets/paint_widgets.dart';
import 'paint_list_detail_screen.dart';

/// The user's own paint lists — one per miniature, unit or army.
///
/// The built-in shopping list lives elsewhere (its own icon next to the
/// avatar): it is derived from inventory status rather than a document a
/// user created, so mixing it in here would blur "things I made" with
/// "things PintaMinis computes for me".
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lists = context.watch<PaintListsProvider>();
    final inventory = context.watch<InventoryProvider>();

    return SafeArea(
      child: Stack(
        children: [
          if (lists.lists.isEmpty)
            EmptyState(
              icon: Icons.checklist_rtl,
              title: l10n.listsEmptyTitle,
              body: l10n.listsEmptyBody,
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              children: [
                for (final list in lists.lists)
                  _PaintListCard(
                    list: list,
                    readiness: list.readiness(inventory.entries),
                  ),
              ],
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'lists-new',
              onPressed: () => _createList(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.listsNew),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createList(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<PaintListsProvider>();

    final name = await showListNameDialog(context, title: l10n.listsNew);
    if (name == null || name.isEmpty) return;

    await provider.create(name);
    messenger.showSnackBar(SnackBar(content: Text(l10n.listsCreated)));
  }
}

class _PaintListCard extends StatelessWidget {
  const _PaintListCard({required this.list, required this.readiness});

  final PaintList list;
  final PaintListReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PaintListDetailScreen(listId: list.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(list.name, style: theme.textTheme.titleMedium),
                  ),
                  PaintListStatusChip(readiness: readiness),
                ],
              ),
              const SizedBox(height: 8),
              PaintListReadinessBar(readiness: readiness),
              const SizedBox(height: 8),
              Text(
                l10n.listPaintCount(readiness.total),
                style: theme.textTheme.bodySmall,
              ),
              if (readiness.total > 0)
                Text(
                  readinessDetailText(l10n, readiness),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (readiness.needsShopping) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.listNeedsBuying(readiness.needsBuying),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared name prompt used for both creating and renaming a list.
Future<String?> showListNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.listsNameLabel,
          hintText: l10n.listsNameHint,
        ),
        onSubmitted: (value) =>
            Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(l10n.actionSave),
        ),
      ],
    ),
  );
}
