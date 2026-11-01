import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/ui/widgets.dart';

void main() {
  testWidgets('compact checkbox tap target matches the box', (tester) async {
    var value = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => CompactCheckbox(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    ));

    final checkbox = find.byType(CompactCheckbox);
    expect(tester.getSize(checkbox), const Size(16, 16));
    final center = tester.getCenter(checkbox);

    await tester.tapAt(center + const Offset(12, 0));
    await tester.pump();
    expect(value, isFalse);

    await tester.tapAt(center);
    await tester.pump();
    expect(value, isTrue);
  });
}
