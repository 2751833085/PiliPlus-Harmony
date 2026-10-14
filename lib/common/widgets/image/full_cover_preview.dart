import 'package:flutter/material.dart';

class FullCoverPreview extends StatelessWidget {
  const FullCoverPreview({
    super.key,
    required this.image,
    required this.width,
    required this.maxHeight,
  });
  final ImageProvider image;
  final double width;
  final double maxHeight;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Image(
        image: image,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, error, stack) => SizedBox(
          width: width,
          height: width / (16 / 9),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    ),
  );
}
