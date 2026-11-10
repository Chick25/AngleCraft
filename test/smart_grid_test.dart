import 'package:angle_craft/widgets/smart_grid.dart';
import 'package:angle_craft/widgets/smart_grid_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints every supported grid type', (tester) async {
    for (final gridType in GridType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SmartGridWidget(gridType: gridType)),
        ),
      );
      await tester.pumpAndSettle();

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is SmartGridPainter,
        ),
      );
      expect((customPaint.painter! as SmartGridPainter).gridType, gridType);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('hides the painter when the grid is disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartGridWidget(showGrid: false))),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SmartGridPainter,
      ),
      findsNothing,
    );
  });
}
