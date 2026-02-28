import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/core/extensions.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/models/enums.dart';
import 'package:sync_ledger/presentation/providers/transaction_providers.dart';
import 'package:sync_ledger/presentation/widgets/category_picker.dart';

class TransactionsFilterArgs {
  const TransactionsFilterArgs({
    required this.type,
    required this.query,
  });

  final TransactionType? type;
  final String query;
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _filterType;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txns = ref.watch(
      filteredTransactionsProvider((
        type: _filterType,
        query: _searchQuery,
      ),),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterType == null,
                onSelected: () => setState(() => _filterType = null),
              ),
              for (final t in TransactionType.values)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChip(
                    label: t.name[0].toUpperCase() + t.name.substring(1),
                    selected: _filterType == t,
                    onSelected: () => setState(() => _filterType = t),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: txns.when(
            data: (list) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(filteredTransactionsProvider),
              child: list.isEmpty
                  ? const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 300,
                        child: Center(child: Text('No transactions yet')),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _TransactionTile(transaction: list[i]),
                    ),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = transaction.direction == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final prefix = isIncome ? '+' : '-';
    final date = DateTime.fromMillisecondsSinceEpoch(transaction.occurredAtMs);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        transaction.merchant ?? transaction.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${date.toShortDateTime()} · ${transaction.category ?? "Other"}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        '$prefix ${transaction.amount.toCurrencyString(symbol: transaction.currency)}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _showEditSheet(context, ref),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionEditSheet(transaction: transaction),
    );
  }
}

class _TransactionEditSheet extends ConsumerStatefulWidget {
  const _TransactionEditSheet({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_TransactionEditSheet> createState() =>
      _TransactionEditSheetState();
}

class _TransactionEditSheetState
    extends ConsumerState<_TransactionEditSheet> {
  late CategoryTag _category;
  bool _learnRule = false;

  @override
  void initState() {
    super.initState();
    _category = CategoryTag.values.firstWhere(
      (c) => c.name == widget.transaction.category,
      orElse: () => CategoryTag.other,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Transaction', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          CategoryPicker(
            selected: _category,
            onChanged: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),
          if (widget.transaction.merchant != null) ...[
            SwitchListTile(
              title: const Text('Learn this rule'),
              subtitle: Text(
                'Apply "${_category.displayName}" for future '
                '"${widget.transaction.merchant}" transactions',
              ),
              value: _learnRule,
              onChanged: (v) => setState(() => _learnRule = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ref.read(transactionActionsProvider).updateCategory(
                      widget.transaction.id,
                      _category,
                      learnRule: _learnRule,
                      merchant: widget.transaction.merchant,
                    );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
