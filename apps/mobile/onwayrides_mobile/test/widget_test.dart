import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onwayrides_mobile/app/onway_app.dart';

void main() {
  testWidgets('renders the OnWay rider shell in preview mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: OnWayShell(previewMode: true)),
    );

    expect(find.text('Quick services'), findsOneWidget);
    expect(find.text('Driver Mode'), findsOneWidget);
  });
}
