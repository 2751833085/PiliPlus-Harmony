import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:flutter/material.dart';

/// Local to this video: loading never masks the route's back action, and a
/// failed native open exposes retry instead of leaving an endless spinner.
class PlaybackRequestOverlay extends StatelessWidget {
  const PlaybackRequestOverlay({
    super.key,
    required this.pending,
    required this.failed,
    required this.onRetry,
    required this.onBack,
  });
  final bool pending, failed;
  final VoidCallback onRetry, onBack;

  @override
  Widget build(BuildContext context) {
    if (!pending && !failed) return const SizedBox.shrink();
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            Center(
              child: failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '播放加载失败，请重试',
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('重试播放'),
                        ),
                      ],
                    )
                  : const HarmonyLoadingIndicator(size: 24),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: IconButton(
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
