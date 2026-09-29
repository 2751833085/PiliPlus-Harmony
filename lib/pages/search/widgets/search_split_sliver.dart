import 'package:flutter/material.dart';

class SearchSplitSliver extends StatelessWidget {
  const SearchSplitSliver({super.key, required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => SliverCrossAxisGroup(
    slivers: [
      SliverCrossAxisExpanded(flex: 3, sliver: left),
      const SliverConstrainedCrossAxis(
        maxExtent: 24,
        sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
      SliverCrossAxisExpanded(flex: 2, sliver: right),
    ],
  );
}
