import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/pages/video/reply/widgets/zan_grpc.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'helpers/memory_box.dart';

void main() {
  setUp(() => GStorage.setting = MemoryBox());
  testWidgets(
    'comment dislike totals are opt-in and cannot be inferred from action or likes',
    (tester) async {
      final reply = ReplyInfo(
        like: Int64(31),
        count: Int64(72),
        replyControl: ReplyControl(action: Int64(2)),
      );
      expect(Pref.showReplyDislikeCount, false);
      Future<void> render() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: ZanButtonGrpc(replyItem: reply)),
          ),
        ),
      );
      await render();
      expect(find.text('未公开'), findsNothing);
      await GStorage.setting.put(SettingBoxKey.showReplyDislikeCount, true);
      await render();
      expect(find.text('未公开'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('72'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
