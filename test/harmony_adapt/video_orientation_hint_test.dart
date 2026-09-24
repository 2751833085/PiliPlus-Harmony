import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';

class Item extends BaseRcmdVideoItemModel {}

void main() {
  test(
    'portrait badge uses source dimensions and rotation, never cover shape',
    () {
      expect((Item()..readDimension({})).isPortraitVideo, isFalse);
      expect(
        (Item()..readDimension({
              'dimension': {'width': 1920, 'height': 1080},
            }))
            .isPortraitVideo,
        isFalse,
      );
      expect(
        (Item()..readDimension({
              'dimension': {'width': 1920, 'height': 1080, 'rotate': 1},
            }))
            .isPortraitVideo,
        isTrue,
      );
      expect(
        (Item()..readDimension({
              'uri':
                  'bilibili://video/1?player_width=720&player_height=1280&player_rotate=1',
            }))
            .isPortraitVideo,
        isFalse,
      );
      expect(
        (Item()..readDimension({
              'dimension': {'width': 0, 'height': 0},
            }))
            .isPortraitVideo,
        isFalse,
      );
    },
  );
}
