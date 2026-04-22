import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_studio/main.dart';

void main() {
  testWidgets('editor shell renders and can add a frame', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GifStudioApp());

    expect(find.text('Gif Studio'), findsOneWidget);
    expect(find.text('画布预览'), findsOneWidget);
    expect(find.text('单帧编辑'), findsOneWidget);
    expect(find.text('Frame 01'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('frame-summary'))).data,
      startsWith('6 帧'),
    );

    await tester.tap(find.byKey(const ValueKey('add-frame-button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('frame-summary'))).data,
      startsWith('7 帧'),
    );
    expect(find.textContaining('第 7 / 7 帧'), findsOneWidget);
  });

  testWidgets('timeline supports ctrl multi-select and batch editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GifStudioApp());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Frame 02'));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(find.text('批量编辑'), findsOneWidget);
    expect(find.textContaining('当前已选 2 帧'), findsOneWidget);
    expect(find.text('删除选中帧'), findsOneWidget);
  });

  testWidgets('timeline supports ctrl a select all', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GifStudioApp());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(find.text('批量编辑'), findsOneWidget);
    expect(find.textContaining('当前已选 6 帧'), findsOneWidget);
  });
}
