import 'package:flutter/material.dart';

/// One cell of a [ComparisonGrid]. A [flag] draws it in the warning colour.
class GridCell {
  const GridCell(this.text, {this.flag = false});

  final String text;
  final bool flag;
}

/// One row: a name and a cell per column.
class GridRow {
  const GridRow(this.label, this.cells);

  final String label;
  final List<GridCell> cells;
}

/// A titled table that scrolls sideways when it is wider than the screen, so
/// it stays readable at phone width.
class ComparisonGrid extends StatelessWidget {
  const ComparisonGrid({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.caption,
    this.labelWidth = 150,
    this.cellWidth = 92,
  });

  final String title;
  final List<String> columns;
  final List<GridRow> rows;
  final String? caption;
  final double labelWidth;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FixedColumnWidth(labelWidth),
                  for (var i = 0; i < columns.length; i++)
                    i + 1: FixedColumnWidth(cellWidth),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                children: [
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      for (final column in columns)
                        _cell(
                          column,
                          theme.textTheme.labelMedium?.copyWith(color: muted),
                        ),
                    ],
                  ),
                  for (final row in rows)
                    TableRow(
                      children: [
                        _cell(
                          row.label,
                          theme.textTheme.bodyMedium,
                          left: true,
                        ),
                        for (final cell in row.cells)
                          _cell(
                            cell.text,
                            theme.textTheme.bodyMedium?.copyWith(
                              color: cell.flag ? theme.colorScheme.error : null,
                              fontWeight: cell.flag ? FontWeight.bold : null,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, TextStyle? style, {bool left = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(
      text,
      style: style,
      textAlign: left ? TextAlign.start : TextAlign.end,
    ),
  );
}
