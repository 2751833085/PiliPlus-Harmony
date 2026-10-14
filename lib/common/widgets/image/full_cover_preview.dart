import 'dart:math' as math;
import 'package:flutter/material.dart';

class FullCoverPreview extends StatelessWidget {
  const FullCoverPreview({
    super.key,
    required this.image,
    required this.width,
    required this.maxHeight,
    this.aspectRatio = 16 / 9,
  });
  final ImageProvider image;
  final double width;
  final double maxHeight;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) {
    final ratio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : 16 / 9;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SizedBox(
        width: width,
        height: math.min(width / ratio, maxHeight),
        child: Image(
          image: image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stack) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}
