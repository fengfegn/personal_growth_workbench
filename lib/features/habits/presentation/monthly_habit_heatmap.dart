import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../domain/habit_stats.dart';

class MonthlyHabitHeatmap extends StatelessWidget {
  const MonthlyHabitHeatmap({
    required this.year,
    required this.month,
    required this.cells,
    required this.onCellTap,
    this.selectedDate,
    this.compact = false,
    super.key,
  });

  final int year;
  final int month;
  final List<HabitHeatmapCell> cells;
  final ValueChanged<HabitHeatmapCell> onCellTap;
  final String? selectedDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cellByDate = {for (final cell in cells) cell.date: cell};
    final firstDay = DateTime(year, month, 1);
    final leadingEmpty = firstDay.weekday - 1;
    final dayCount = DateTime(year, month + 1, 0).day;
    final totalCells = ((leadingEmpty + dayCount + 6) ~/ 7) * 7;
    final cellHeight = compact ? 34.0 : 54.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: compact ? 5 : 8,
            mainAxisSpacing: compact ? 5 : 8,
            mainAxisExtent: cellHeight,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingEmpty + 1;
            final date = day < 1 || day > dayCount
                ? null
                : localDateKey(DateTime(year, month, day));
            final cell = date == null ? null : cellByDate[date];
            return _HabitHeatmapCell(
              cell: cell,
              selected: date != null && date == selectedDate,
              compact: compact,
              onTap: cell == null || cell.isFuture
                  ? null
                  : () => onCellTap(cell),
            );
          },
        ),
      ],
    );
  }
}

class _HabitHeatmapCell extends StatelessWidget {
  const _HabitHeatmapCell({
    required this.cell,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final HabitHeatmapCell? cell;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final item = cell;
    final theme = Theme.of(context);
    final label = item == null
        ? '无日期'
        : item.isFuture
        ? '${item.date}，未来日期'
        : item.isEmpty
        ? '${item.date}，当天没有有效习惯'
        : '${item.date}，完成 ${item.completedCount} / ${item.activeCount}，完成率 ${(item.rate * 100).round()}%';

    return Semantics(
      button: item != null,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                color: item == null
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.26,
                      )
                    : _heatmapColor(context, item),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : item == null
                      ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: item == null
                  ? null
                  : Center(
                      child: Text(
                        item.date.substring(8),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: item.isFuture
                              ? theme.colorScheme.onSurfaceVariant
                              : item.level >= 4
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 14,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _heatmapColor(BuildContext context, HabitHeatmapCell cell) {
  final scheme = Theme.of(context).colorScheme;
  if (cell.isFuture) {
    return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
  }
  if (cell.level < 0) return scheme.surfaceContainerHighest;
  return Color.lerp(
    scheme.surfaceContainerHighest,
    scheme.primary,
    [0.08, 0.25, 0.45, 0.65, 0.82, 1.0][cell.level.clamp(0, 5)],
  )!;
}
