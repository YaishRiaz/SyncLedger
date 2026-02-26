import 'package:flutter/material.dart';
import 'package:sync_ledger/domain/models/enums.dart';

class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CategoryTag selected;
  final ValueChanged<CategoryTag> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CategoryTag.values.map((cat) {
        return ChoiceChip(
          label: Text(cat.displayName),
          selected: selected == cat,
          onSelected: (_) => onChanged(cat),
        );
      }).toList(),
    );
  }
}
