import 'dart:math' show max;
import 'package:PiliPlus/common/style.dart';

/// Shared cover geometry for horizontal cards and their loading placeholders.
abstract final class VideoCardHLayout {
  static double coverWidth(
    double availableWidth,
    double availableHeight, {
    bool compactSidebar = false,
  }) => (availableWidth * (compactSidebar ? .50 : .46))
      .clamp(96.0, compactSidebar ? 196.0 : 184.0)
      .clamp(0.0, availableHeight * Style.aspectRatio);

  /// Grow only for accessibility text, rather than reserving blank title space.
  static double compactRowExtent({
    required double titleFontSize,
    required double metadataFontSize,
  }) => max(
    104,
    titleFontSize * 1.28 * 2 +
        metadataFontSize +
        max(40, metadataFontSize * 1.25 * 2) +
        14,
  );
}
