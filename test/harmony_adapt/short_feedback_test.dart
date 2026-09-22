import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:PiliPlus/pages/video/shorts/feedback.dart';
import 'package:PiliPlus/pages/video/shorts/session.dart';
import 'package:PiliPlus/pages/video/reply/widgets/panel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  setUpAll(() async {
    const font = String.fromEnvironment('SHORTS_PREVIEW_FONT');
    const icons = String.fromEnvironment('SHORTS_PREVIEW_ICONS');
    for (final entry in {'preview': font, 'MaterialIcons': icons}.entries) {
      if (entry.value.isNotEmpty) {
        await (FontLoader(entry.key)..addFont(
              File(entry.value).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    }
  });
  const a = ShortVideoEntry(bvid: 'a'),
      b = ShortVideoEntry(bvid: 'b'),
      c = ShortVideoEntry(bvid: 'c'),
      d = ShortVideoEntry(bvid: 'd');
  test(
    'dismiss middle and last slots without losing previous navigation; filter and restore',
    () async {
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [a, b, c, d],
        loadFresh: () async => [a, b, c, d, const ShortVideoEntry(bvid: 'e')],
        accepts: (entry) => entry.bvid != 'd',
        play: (_) async => true,
      );
      await session.loadMore();
      await session.select(1);
      expect(await session.dismissCurrent(), isTrue);
      expect(session.index, 1);
      expect(session.entries.map((e) => e.bvid), ['a', 'c']);
      await session.select(0);
      await session.select(1);
      expect(session.current.bvid, 'c');
      expect(await session.dismissCurrent(), isTrue);
      expect(session.entries.map((e) => e.bvid), ['a', 'e']);
      await session.loadMore();
      expect(session.entries.map((e) => e.bvid), ['a', 'e']);
      session.restoreHidden();
      await session.loadMore();
      expect(session.entries.map((e) => e.bvid), ['a', 'e', 'b', 'c']);
      session.dispose();
    },
  );
  test(
    'failed replacement is retryable; stale metadata cannot reintroduce dismissed video',
    () async {
      final stale = Completer<List<ShortVideoEntry>>();
      var accepted = false;
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) => stale.future,
        loadFresh: () async => [b],
        play: (_) async => accepted,
      );
      final old = session.loadMore();
      expect(await session.dismissCurrent(), isFalse);
      expect(session.current.bvid, 'a');
      expect(session.dismissing, isFalse);
      accepted = true;
      expect(await session.dismissCurrent(), isTrue);
      stale.complete([a, c]);
      await old;
      expect(session.entries.map((e) => e.bvid), ['b']);
      session.dispose();
    },
  );
  test(
    'dismiss serializes with playback, refresh, actions, and disposal',
    () async {
      final playing = Completer<bool>();
      final session = ShortVideoSession(
        initial: a,
        loadRelated: (_) async => [b],
        loadFresh: () async => [c],
        play: (_) => playing.future,
      );
      await session.loadMore();
      final pending = session.dismissCurrent();
      expect(await session.dismissCurrent(), isFalse);
      expect(await session.select(1), isFalse);
      expect(await session.refresh(), isFalse);
      await session.interact(() => fail('locked'));
      session.dispose();
      playing.complete(true);
      expect(await pending, isFalse);
    },
  );
  test(
    'hide reasons survive reopening storage, stay bounded, and clear independently',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'short-feedback-',
      );
      Hive.init(directory.path);
      var box = await Hive.openBox<dynamic>('feedback');
      var feedback = ShortVideoFeedback(box);
      await box.put('unrelatedPreference', true);
      await feedback.hide('a', ShortVideoHideReason.watched);
      await box.close();
      box = await Hive.openBox<dynamic>('feedback');
      feedback = ShortVideoFeedback(box);
      expect(feedback.allows('a'), isFalse);
      expect(feedback.records['a'], 'watched');
      await box.put('shortVideoHiddenVideos', {
        for (var i = 0; i < 1000; i++) '$i': 'watched',
      });
      await feedback.hide('new', ShortVideoHideReason.uninterested);
      expect(feedback.records.length, 1000);
      expect(feedback.allows('0'), isTrue);
      await feedback.clear();
      expect(feedback.allows('new'), isTrue);
      expect(box.get('unrelatedPreference'), isTrue);
      await box.close();
      await directory.delete(recursive: true);
    },
  );
  testWidgets(
    'feedback sheet selects a reason, cancels without feedback, and offers restore',
    (tester) async {
      Object? result;
      final capture = GlobalKey();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'preview'),
          builder: (_, child) => RepaintBoundary(key: capture, child: child),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        const ShortVideoFeedbackSheet(hiddenCount: 2),
                  );
                },
                child: const Text('菜单'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('菜单'));
      await tester.pumpAndSettle();
      await capturePreview(tester, capture, 'feedback');
      await tester.tap(find.text('已经看过了'));
      await tester.pumpAndSettle();
      expect(result, ShortVideoHideReason.watched);
      await tester.tap(find.text('菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复本机已隐藏的视频（2）'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );
  testWidgets(
    'compact comment title, sort and close occupy one accessible row',
    (tester) async {
      var sorts = 0, closes = 0;
      final capture = GlobalKey();
      for (final scale in [1.0, 1.8]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'preview'),
            builder: (_, child) => RepaintBoundary(key: capture, child: child),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: ReplyPanelHeader(
                      title: '热门评论',
                      sortLabel: '最热',
                      onSort: () => sorts++,
                      onClose: () => closes++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await capturePreview(tester, capture, 'comment-header-$scale');
        expect(
          tester.getSize(find.byType(ReplyPanelHeader)).height,
          lessThanOrEqualTo(56),
        );
        expect(
          tester.getSize(find.byTooltip('关闭评论')).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('最热'));
        await tester.tap(find.byTooltip('关闭评论'));
        expect(tester.takeException(), isNull);
      }
      expect(sorts, 2);
      expect(closes, 2);
    },
  );
}

Future<void> capturePreview(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  const path = String.fromEnvironment('SHORTS_RENDER_PATH');
  if (path.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$path-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
