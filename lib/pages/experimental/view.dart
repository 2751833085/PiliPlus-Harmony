import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:flutter/widgets.dart';

/// Compatibility entry for older links; Harmony settings now live in Other.
class ExperimentalPage extends StatelessWidget {
  const ExperimentalPage({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  Widget build(BuildContext context) => CommonSetting(
    settingType: SettingType.extraSetting,
    showAppBar: showAppBar,
  );
}
