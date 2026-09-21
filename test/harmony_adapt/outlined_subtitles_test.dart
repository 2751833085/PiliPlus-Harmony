import 'dart:async';

import 'package:PiliPlus/harmony_adapt/outlined_subtitles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subtitle updates render one fill and one configurable stroke', (
    tester,
  ) async {
    final stream = StreamController<List<String>>();
    Widget view({double stroke = 3, bool visible = true}) => MaterialApp(
      home: OutlinedSubtitles(
        subtitles: stream.stream,
        initialSubtitles: const [' first ', '', '第二行'],
        style: const TextStyle(color: Colors.white, fontSize: 24),
        strokeWidth: stroke,
        visible: visible,
      ),
    );
    await tester.pumpWidget(view());
    expect(find.text('first\n第二行'), findsNWidgets(2));
    final texts = tester.widgetList<Text>(find.text('first\n第二行')).toList();
    expect(texts.first.style!.foreground!.style, PaintingStyle.stroke);
    expect(texts.first.style!.foreground!.strokeWidth, 3);
    expect(texts.last.style!.color, Colors.white);
    expect(
      find.ancestor(
        of: find.text('first\n第二行').first,
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    stream.add(['next']);
    await tester.pump();
    expect(find.text('next'), findsNWidgets(2));
    await tester.pumpWidget(view(stroke: 0));
    expect(find.text('next'), findsOneWidget);
    await tester.pumpWidget(view(visible: false));
    expect(find.text('next'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(stream.close());
    await tester.pump();
  });

  testWidgets('empty subtitles leave no text or stroke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OutlinedSubtitles(
          subtitles: Stream<List<String>>.empty(),
          initialSubtitles: [' ', '\n'],
          style: TextStyle(color: Colors.white),
          strokeWidth: 3,
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
