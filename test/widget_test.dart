import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wheel/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RandomSelectorApp());
  }

  testWidgets('shows names and a spin button', (tester) async {
    await pumpApp(tester);

    expect(find.text('Spin'), findsOneWidget);
    expect(find.textContaining('4 names'), findsOneWidget);
  });

  testWidgets('spinning picks a winner and allows removing it', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Spin'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 3)); // let confetti finish

    expect(find.text('Spin again'), findsOneWidget);
    expect(find.text('Spin again without winner'), findsOneWidget);

    await tester.tap(find.text('Spin again without winner'));
    await tester.pump();
    expect(find.textContaining('3 names'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 3));
  });
}
