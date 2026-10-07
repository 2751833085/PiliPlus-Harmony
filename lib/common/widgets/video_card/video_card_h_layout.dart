import 'package:PiliPlus/common/style.dart';

/// Shared cover geometry for horizontal cards and their loading placeholders.
abstract final class VideoCardHLayout {
  static double coverWidth(double availableWidth, double availableHeight) =>
      (availableWidth * .46)
          .clamp(96.0, 184.0)
          .clamp(0.0, availableHeight * Style.aspectRatio);
}
