import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/ui/widgets.dart';

class _ResizeHarness extends StatefulWidget {
  const _ResizeHarness();

  @override
  State<_ResizeHarness> createState() => _ResizeHarnessState();
}

class _ResizeHarnessState extends State<_ResizeHarness> {
  double _width = 200;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(key: const Key('panel'), width: _width, child: const ColoredBox(color: Colors.grey)),
        ResizeHandle(
          width: 6,
          onDrag: (delta) => setState(() => _width += delta),
        ),
        const Expanded(child: ColoredBox(color: Colors.white)),
      ],
    );
  }
}

void main() {
  testWidgets('resize handle emits every pointer delta without drag slop', (tester) async {
    final deltas = <double>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: Row(
              children: [
                ResizeHandle(width: 6, onDrag: deltas.add),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    ));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(ResizeHandle)));
    await gesture.moveBy(const Offset(2, 0));
    await gesture.moveBy(const Offset(3, 0));
    await gesture.moveBy(const Offset(-1, 0));
    await gesture.up();

    expect(deltas, [2.0, 3.0, -1.0]);
  });

  testWidgets('resize drag continues after the pointer leaves the handle', (tester) async {
    final deltas = <double>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: Row(
              children: [
                ResizeHandle(width: 6, onDrag: deltas.add),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    ));

    final start = tester.getCenter(find.byType(ResizeHandle));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(start);
    await gesture.moveTo(start + const Offset(120, 60));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();

    expect(deltas, [120.0, 10.0]);
  });

  testWidgets('panel width tracks the sum of deltas before the next frame', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: _ResizeHarness()),
    ));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(tester.getCenter(find.byType(ResizeHandle)));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(15, 0));
    await gesture.moveBy(const Offset(5, 0));
    await gesture.up();
    await tester.pump();

    expect(tester.getSize(find.byKey(const Key('panel'))).width, 230);
  });
}
