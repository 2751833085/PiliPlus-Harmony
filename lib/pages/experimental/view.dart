import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_settings_list.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/setting/models/experimental_settings.dart';
import 'package:flutter/material.dart';

class ExperimentalPage extends StatefulWidget {
  const ExperimentalPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<ExperimentalPage> createState() => _ExperimentalPageState();
}

class _ExperimentalPageState extends State<ExperimentalPage> {
  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: const Text('鸿蒙特色功能')) : null,
      body: ValueListenableBuilder<int>(
        valueListenable: HarmonyAppearance.revision,
        builder: (context, _, _) {
          final settings = experimentalSettings;
          return HarmonySettingsList(
            sectionBuilder: (index) => settings[index].section,
            padding: EdgeInsets.only(
              left: showAppBar ? padding.left : 0,
              right: showAppBar ? padding.right : 0,
              bottom: padding.bottom + 100,
            ),
            itemCount: settings.length,
            itemBuilder: (context, index) => settings[index].widget,
          );
        },
      ),
    );
  }
}
