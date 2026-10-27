import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart' as im;
import 'package:PiliPlus/grpc/bilibili/dagw/component/avatar/v1.pb.dart'
    as avatar;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/immersive_row_interaction.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/models_new/history/history.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/later/data.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/common/multi_select/multi_select_controller.dart';
import 'package:PiliPlus/pages/fav/video/widgets/item.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:PiliPlus/pages/later/widgets/video_card_h_later.dart';
import 'package:PiliPlus/pages/setting/widgets/normal_item.dart';
import 'package:PiliPlus/pages/whisper/widgets/item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'helpers/memory_box.dart';

class _HistorySelection implements MultiSelectBase<HistoryItemModel> {
  @override
  final enableMultiSelect = true.obs;
  int taps = 0;
  @override
  int get checkedCount => 0;
  @override
  void onSelect(HistoryItemModel item) => taps++;
  @override
  void handleSelect({bool checked = false, bool disableSelect = true}) {}
  @override
  void onRemove() {}
}

class _LaterSelection extends MultiSelectController<LaterData, LaterItemModel>
    with BaseLaterController {
  int taps = 0;
  @override
  Future<LoadingState<LaterData>> customGetData() async =>
      const Error('not used');
  @override
  void onSelect(LaterItemModel item) => taps++;
}

void main() {
  setUpAll(() => GStorage.setting = MemoryBox());
  testWidgets(
    'actual core rows retain taps, scroll and geometry with fixed touch light',
    (tester) async {
      final history = _HistorySelection();
      final later = _LaterSelection()..enableMultiSelect.value = true;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      addTearDown(later.scrollController.dispose);
      var favouriteTaps = 0, conversationTaps = 0, settingTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmonyTheme.apply(ThemeData.light(), immersive: true),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                SizedBox(
                  height: 120,
                  child: HistoryItem(
                    item: HistoryItemModel(
                      title: '历史条目',
                      cover: '',
                      history: History(business: 'archive'),
                    ),
                    ctr: history,
                    onDelete: (_, __) {},
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: FavVideoItem(
                    heroTag: 'fav-row-test',
                    item: FavFolderInfo(title: '收藏夹', mediaCount: 2),
                    onTap: () => favouriteTaps++,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: VideoCardHLater(
                    ctr: later,
                    index: 0,
                    onViewLater: (_) {},
                    videoItem: LaterItemModel(
                      title: '稍后条目',
                      pic: '',
                      owner: Owner(name: '作者'),
                    ),
                  ),
                ),
                WhisperSessionItem(
                  item: im.Session(
                    id: im.SessionId(
                      privateId: im.PrivateId(talkerUid: Int64(42)),
                    ),
                    sessionInfo: im.SessionInfo(
                      sessionName: '会话条目',
                      avatar: avatar.AvatarItem(
                        fallbackLayers: avatar.LayerGroup(
                          layers: [
                            avatar.Layer(
                              resource: avatar.BasicLayerResource(
                                resImage: avatar.ResImage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onSetTop: (_, __) {},
                  onSetMute: (_, __) {},
                  onRemove: (_) {},
                  onOpen: (_) => conversationTaps++,
                ),
                NormalItem(title: '设置条目', onTap: (_, __) => settingTaps++),
                const SizedBox(height: 1800),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImmersiveRowInteraction), findsNWidgets(5));
      expect(find.byType(BackdropFilter), findsNothing);
      for (final label in ['历史条目', '收藏夹', '稍后条目', '会话条目', '设置条目']) {
        final text = find.text(label);
        final before = tester.getRect(text);
        final gesture = await tester.startGesture(before.center);
        await gesture.moveBy(const Offset(9, 2));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getRect(text),
          before,
          reason: '$label must not move with touch light',
        );
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(history.taps, 1);
      expect(favouriteTaps, 1);
      expect(later.taps, 1);
      expect(conversationTaps, 1);
      expect(settingTaps, 1);
      final before = tester.getTopLeft(find.text('收藏夹')).dy + scroll.offset;
      await tester.drag(find.text('收藏夹'), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(
        tester.getTopLeft(find.text('收藏夹')).dy + scroll.offset,
        closeTo(before, .01),
      );
      expect(favouriteTaps, 1, reason: 'scroll must not trigger a row tap');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabled immersive and accessibility modes bypass row feedback',
    (tester) async {
      var taps = 0;
      Rect? original;
      for (final mode in ['on', 'off', 'reduced motion', 'high contrast']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(
              ThemeData.dark(),
              immersive: mode != 'off',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: mode == 'reduced motion',
                highContrast: mode == 'high contrast',
              ),
              child: child!,
            ),
            home: Scaffold(
              body: NormalItem(title: '普通设置', onTap: (_, __) => taps++),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(ImmersiveRowInteraction);
        final feedback = find.descendant(
          of: row,
          matching: find.byType(ImmersiveInteraction),
        );
        expect(
          feedback,
          mode == 'on' ? findsOneWidget : findsNothing,
          reason: mode,
        );
        if (mode == 'on') {
          expect(
            tester.widget<ImmersiveInteraction>(feedback).allowMovement,
            isFalse,
          );
        }
        final rect = tester.getRect(find.text('普通设置'));
        original ??= rect;
        expect(rect, original, reason: 'feedback cannot alter row layout');
        await tester.tap(find.text('普通设置'));
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(taps, 4);
    },
  );
  testWidgets(
    'later rows tolerate unknown or zero duration with saved progress',
    (tester) async {
      final later = _LaterSelection()..enableMultiSelect.value = true;
      addTearDown(later.scrollController.dispose);
      for (final duration in <int?>[null, 0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: HarmonyTheme.apply(ThemeData.light(), immersive: true),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 500,
                  height: 120,
                  child: VideoCardHLater(
                    ctr: later,
                    index: 0,
                    onViewLater: (_) {},
                    videoItem: LaterItemModel(
                      title: '未知时长',
                      pic: '',
                      duration: duration,
                      progress: 10,
                      owner: Owner(name: '作者'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('未知时长'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
