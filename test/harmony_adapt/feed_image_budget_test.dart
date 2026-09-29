import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/common/widgets/image/feed_image_budget.dart';

void main() {
  testWidgets('feed decode budget reduces density without changing layout or detail routes', (tester) async {
    int? feed, detail, large;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2.875),
      child: Directionality(textDirection: TextDirection.ltr, child: Column(children: [
        FeedImageBudget(child: Builder(builder: (context) {
          feed = FeedImageBudget.cacheSize(context, 300);
          large = FeedImageBudget.cacheSize(context, 1000);
          return const SizedBox(width: 300, height: 200, key: ValueKey('cover'));
        })),
        Builder(builder: (context) {
          detail = FeedImageBudget.cacheSize(context, 300);
          return const SizedBox();
        }),
      ])),
    ));
    expect(feed, 675);
    expect(large, 1280);
    expect(detail, 863);
    expect(tester.getSize(find.byKey(const ValueKey('cover'))), const Size(300, 200));
  });
}
