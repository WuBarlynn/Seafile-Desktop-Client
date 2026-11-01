import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets.dart';

List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var index = 0;
  while (index < input.length) {
    final char = input[index];
    if (inQuotes) {
      if (char == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index += 2;
          continue;
        }
        inQuotes = false;
        index++;
        continue;
      }
      field.write(char);
      index++;
      continue;
    }
    if (char == '"') {
      inQuotes = true;
      index++;
      continue;
    }
    if (char == ',') {
      row.add(field.toString());
      field.clear();
      index++;
      continue;
    }
    if (char == '\r') {
      index++;
      continue;
    }
    if (char == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
      index++;
      continue;
    }
    field.write(char);
    index++;
  }
  row.add(field.toString());
  if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
  if (rows.isNotEmpty &&
      rows.last.length == 1 &&
      rows.last.first.isEmpty &&
      (input.endsWith('\n') || input.endsWith('\r'))) {
    rows.removeLast();
  }
  return rows;
}

class CsvTableView extends StatefulWidget {
  const CsvTableView({super.key, required this.text});

  final String text;

  @override
  State<CsvTableView> createState() => _CsvTableViewState();
}

class _CsvTableViewState extends State<CsvTableView> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = parseCsv(widget.text);
    if (rows.isEmpty) {
      return const Center(
        child: Text('CSV', style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    final columns = rows.fold<int>(1, (max, row) => math.max(max, row.length));
    final widths = List<double>.generate(columns, (column) => _columnWidth(rows, column));
    final rowHeaderWidth = (rows.length.toString().length * 8 + 28).clamp(44, 88).toDouble();
    final tableWidth = rowHeaderWidth + widths.fold<double>(0, (sum, width) => sum + width);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 360.0;
        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontal,
            child: SizedBox(
              width: math.max(tableWidth, constraints.maxWidth),
              height: height,
              child: Column(
                children: [
                  _rowWidget(
                    context,
                    rowIndex: null,
                    cells: rows.first,
                    widths: widths,
                    rowHeaderWidth: rowHeaderWidth,
                    header: true,
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      child: ListView.builder(
                        controller: _vertical,
                        itemCount: rows.length - 1,
                        itemBuilder: (context, index) => _rowWidget(
                          context,
                          rowIndex: index,
                          cells: rows[index + 1],
                          widths: widths,
                          rowHeaderWidth: rowHeaderWidth,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rowWidget(
    BuildContext context, {
    required int? rowIndex,
    required List<String> cells,
    required List<double> widths,
    required double rowHeaderWidth,
    bool header = false,
  }) {
    final background = header
        ? AppColors.tableHeader
        : (rowIndex!.isEven ? Colors.white : const Color(0xFFFAFBFC));
    return HoverBuilder(
      builder: (context, hovered) => Container(
        key: rowIndex == null ? const ValueKey('csv-header') : ValueKey('csv-row-$rowIndex'),
        height: 34,
        decoration: BoxDecoration(
          color: header ? background : (hovered ? AppColors.hover : background),
          border: Border(
            bottom: BorderSide(color: header ? AppColors.borderStrong : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: rowHeaderWidth,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                header ? '#' : '${rowIndex! + 1}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontFamily: 'Menlo'),
              ),
            ),
            for (var column = 0; column < widths.length; column++)
              Container(
                width: widths[column],
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  border: Border(
                    right: column < widths.length - 1
                        ? const BorderSide(color: AppColors.border)
                        : BorderSide.none,
                  ),
                ),
                child: Text(
                  column < cells.length ? cells[column] : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Menlo',
                    fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                    color: header ? AppColors.text : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _columnWidth(List<List<String>> rows, int column) {
    var widest = 0.0;
    final limit = math.min(rows.length, 300);
    for (var row = 0; row < limit; row++) {
      final value = column < rows[row].length ? rows[row][column] : '';
      var width = 0.0;
      for (final rune in value.runes) {
        width += rune >= 0x2E80 ? 13.0 : 7.8;
      }
      if (width > widest) widest = width;
    }
    return (widest + 28).clamp(90.0, 300.0).toDouble();
  }
}
