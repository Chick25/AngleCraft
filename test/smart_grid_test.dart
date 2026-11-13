import 'package:angle_craft/widgets/smart_grid.dart';
import 'package:angle_craft/widgets/grid_alignment_guide.dart';
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

  testWidgets('shows alignment guidance for the selected grid', (tester) async {
    const hints = {
      GridType.thirds: 'Đặt chủ thể gần giao điểm',
      GridType.goldenRatio: 'gần vùng giao nhau',
      GridType.goldenTriangle: 'theo đường chéo và các cạnh tam giác',
      GridType.diagonal: 'theo một đường chéo',
    };

    for (final entry in hints.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GridAlignmentGuide(gridType: entry.key)),
        ),
      );

      expect(find.textContaining(entry.value), findsOneWidget);
    }
  });

  testWidgets('shows live AI advice when composition assistance is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GridAlignmentGuide(
            gridType: GridType.thirds,
            liveAdvice: 'Dịch người sang trái.',
          ),
        ),
      ),
    );

    expect(find.text('Gợi ý AI · Quy tắc 1/3'), findsOneWidget);
    expect(find.text('Dịch người sang trái.'), findsOneWidget);
  });
}
