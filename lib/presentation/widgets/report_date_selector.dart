import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_ledger/presentation/providers/report_providers.dart';

class ReportDateSelectorModal extends ConsumerStatefulWidget {
  final Function(DateRange) onConfirm;

  const ReportDateSelectorModal({
    required this.onConfirm,
    super.key,
  });

  @override
  ConsumerState<ReportDateSelectorModal> createState() =>
      _ReportDateSelectorModalState();

  static Future<DateRange?> show(BuildContext context) {
    return showModalBottomSheet<DateRange>(
      context: context,
      builder: (context) => ReportDateSelectorModal(
        onConfirm: (dateRange) {
          Navigator.of(context).pop(dateRange);
        },
      ),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _ReportDateSelectorModalState extends ConsumerState<ReportDateSelectorModal> {
  late DateTime _customStartDate;
  late DateTime _customEndDate;
  String _selectedOption = 'lastMonth';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customStartDate = DateTime(now.year, now.month - 1, 1);
    _customEndDate = DateTime(now.year, now.month, 0);
  }

  void _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked;
        if (_customStartDate.isAfter(_customEndDate)) {
          _customEndDate = _customStartDate;
        }
      });
    }
  }

  void _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate,
      firstDate: _customStartDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customEndDate = picked;
      });
    }
  }

  void _applyDateRange() {
    final notifier = ref.read(reportDateRangeProvider.notifier);

    switch (_selectedOption) {
      case 'lastMonth':
        notifier.setLastMonth();
        break;
      case 'last30Days':
        notifier.setLast30Days();
        break;
      case 'thisYear':
        notifier.setThisYear();
        break;
      case 'lastYear':
        notifier.setLastYear();
        break;
      case 'custom':
        notifier.setCustomRange(_customStartDate, _customEndDate);
        break;
      case 'customMonth':
        notifier.setMonth(_customStartDate.year, _customStartDate.month);
        break;
    }

    final selectedRange = ref.read(reportDateRangeProvider);
    widget.onConfirm(selectedRange);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Report Date Range',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Preset Options
            Text(
              'Preset Options',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),

            _buildOptionTile(
              'Last Month',
              'Previous calendar month',
              'lastMonth',
              theme,
            ),
            _buildOptionTile(
              'Last 30 Days',
              'Past 30 days from today',
              'last30Days',
              theme,
            ),
            _buildOptionTile(
              'This Year',
              'Jan 1 to today',
              'thisYear',
              theme,
            ),
            _buildOptionTile(
              'Last Year',
              'Full previous year',
              'lastYear',
              theme,
            ),

            const SizedBox(height: 24),

            // Custom Month
            Text(
              'Custom Month',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: const Text('Select Month and Year'),
                subtitle: _selectedOption == 'customMonth'
                    ? Text(
                        '${_monthName(_customStartDate.month)} ${_customStartDate.year}',
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _customStartDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _customStartDate = picked;
                      _selectedOption = 'customMonth';
                    });
                  }
                },
              ),
            ),

            const SizedBox(height: 24),

            // Custom Range
            Text(
              'Custom Range',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_customStartDate),
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: InkWell(
                      onTap: _selectEndDate,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_customEndDate),
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _applyDateRange,
                  child: const Text('Generate Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    String title,
    String subtitle,
    String option,
    ThemeData theme,
  ) {
    final isSelected = _selectedOption == option;
    return Card(
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Radio<String>(
          value: option,
          groupValue: _selectedOption,
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedOption = value);
            }
          },
        ),
        onTap: () {
          setState(() => _selectedOption = option);
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
