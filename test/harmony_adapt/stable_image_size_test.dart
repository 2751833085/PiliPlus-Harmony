import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/image/stable_image_size.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';

void main() {
  test(
    'resizing and returning to a smaller window reuse the upgraded cover',
    () {
      final sizes = [
        600,
        601,
        740,
        600,
        950,
        600,
        950,
      ].map((n) => StableImageSize.resolve('cover-a', n, limit: 1280)).toList();
      expect(sizes, [768, 768, 768, 768, 1024, 1024, 1024]);
      expect(StableImageSize.resolve('different-cover', 300, limit: 1280), 512);
      expect(StableImageSize.resolve('cover-a', 3000, limit: 1280), 1280);
    },
  );
  test('pink is displayed first without swapping stored color identities', () {
    expect(themeColorDisplayOrder.take(2), [1, 0]);
    expect(colorThemeTypes[themeColorDisplayOrder.first].label, '默认粉');
    expect(colorThemeTypes[1].color.toARGB32(), 0xFFFF7299);
    expect(colorThemeTypes[0].color.toARGB32(), 0xFF5CB67B);
  });
}
