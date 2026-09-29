import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/whisper/widgets/message_split.dart';

void main() {
  testWidgets(
    'conversation enters from the right and folding does not replay it',
    (tester) async {
      Widget app(bool selected, {bool split = false, String id = 'one'}) =>
          MaterialApp(
            home: Scaffold(
              body: MessageSplit(
                split: split,
                hasSelection: selected,
                selectionKey: id,
                list: const ColoredBox(color: Colors.red),
                detail: const ColoredBox(
                  key: ValueKey('detail'),
                  color: Colors.blue,
                ),
              ),
            ),
          );
      await tester.pumpWidget(app(false));
      await tester.pumpWidget(app(true));
      expect(tester.getTopLeft(find.byKey(const ValueKey('detail'))).dx, 800);
      await tester.pump(const Duration(milliseconds: 120));
      final x = tester.getTopLeft(find.byKey(const ValueKey('detail'))).dx;
      expect(x, greaterThan(0));
      expect(x, lessThan(800));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('detail'))).dx, 0);
      await tester.pumpWidget(app(true, split: true));
      expect(tester.getTopLeft(find.byKey(const ValueKey('detail'))).dx, 353);
      await tester.pumpWidget(app(true, split: true, id: 'two'));
      expect(tester.getTopLeft(find.byKey(const ValueKey('detail'))).dx, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'folding preserves detail draft, focus and list scroll without zero-width layout',
    (tester) async {
      tester.view.devicePixelRatio = 2.875;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final scroll = ScrollController();
      final text = TextEditingController();
      final focus = FocusNode();
      addTearDown(scroll.dispose);
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      var inits = 0;
      Widget app(bool selected) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final split = MediaQuery.sizeOf(context).width >= 840;
              return MessageSplit(
                split: split,
                hasSelection: selected,
                list: ListView(
                  controller: scroll,
                  children: List.generate(
                    40,
                    (i) => ListTile(title: Text('Conversation $i')),
                  ),
                ),
                detail: _Probe(
                  onInit: () => inits++,
                  child: TextField(controller: text, focusNode: focus),
                ),
              );
            },
          ),
        ),
      );
      tester.view.physicalSize = const Size(3184, 2232);
      await tester.pumpWidget(app(true));
      scroll.jumpTo(240);
      await tester.enterText(find.byType(TextField), '未发送的草稿');
      for (final width in [1008.0, 2048.0, 3184.0, 1008.0]) {
        tester.view.physicalSize = Size(width, 2232);
        await tester.pumpWidget(app(true));
        await tester.pump();
        expect(inits, 1);
        expect(text.text, '未发送的草稿');
        expect(focus.hasFocus, isTrue);
        expect(scroll.offset, 240);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit, required this.child});
  final VoidCallback onInit;
  final Widget child;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
