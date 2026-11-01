import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/ui/widgets.dart';

Color? _iconBackground(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: find.byType(IconAction), matching: find.byType(AnimatedContainer)),
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('icon hover stays light gray while the pointer rests on it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: IconAction(icon: 'more-vertical', tooltip: 'More', onPressed: () {}),
        ),
      ),
    ));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(IconAction)));
    await tester.pump(AppMotion.hover + const Duration(milliseconds: 20));
    expect(_iconBackground(tester), AppColors.hover);

    await tester.pump(const Duration(seconds: 1));
    expect(_iconBackground(tester), AppColors.hover);

    await gesture.moveTo(Offset.zero);
    await tester.pump(AppMotion.hover + const Duration(milliseconds: 20));
    expect(_iconBackground(tester), Colors.transparent);
  });

  test('button hover uses the light neutral surface and a soft transition', () {
    final theme = buildAppTheme();
    for (final style in [
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
      theme.iconButtonTheme.style!,
    ]) {
      expect(style.overlayColor!.resolve({WidgetState.hovered}), AppColors.hover);
      expect(style.animationDuration, AppMotion.hover);
    }
    expect(AppColors.hover.computeLuminance(), greaterThan(const Color(0xFFF5F5F5).computeLuminance()));
  });
}
