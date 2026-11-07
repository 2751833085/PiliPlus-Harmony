import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_settings_list.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class CommonSetting extends StatefulWidget {
  const CommonSetting({
    super.key,
    required this.settingType,
    this.showAppBar = true,
  });

  final bool showAppBar;
  final SettingType settingType;

  @override
  State<CommonSetting> createState() => _CommonSettingState();
}

class _CommonSettingState extends State<CommonSetting> {
  late EdgeInsets padding;
  late List<SettingsModel> settings;
  late List<SettingsModel> _groupedSettings;
  late int _settingsRevision;
  late bool _immersiveEnabled;

  void _initSetting() {
    settings = widget.settingType.settings;
    _settingsRevision = HarmonyAppearance.revision.value;
    _immersiveEnabled = Pref.harmonyImmersive;
    final groups = <String?, List<SettingsModel>>{};
    for (final row in settings) {
      (groups[row.section] ??= <SettingsModel>[]).add(row);
    }
    _groupedSettings = [for (final group in groups.values) ...group];
  }

  @override
  void initState() {
    super.initState();
    _initSetting();
  }

  @override
  void didUpdateWidget(CommonSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingType != oldWidget.settingType) {
      _initSetting();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: Text(widget.settingType.title)) : null,
      body: ValueListenableBuilder<int>(
        valueListenable: HarmonyAppearance.revision,
        builder: (context, revision, _) {
          // Conditional rows refresh on preference changes, not incidental
          // parent builds. Keep initial model construction out of the first
          // route frame a second time, and group rows in one pass.
          // Bulk preference restore can rebuild the parent without sending an
          // appearance revision. Recheck the one mutable membership condition.
          if (_settingsRevision != revision ||
              _immersiveEnabled != Pref.harmonyImmersive) {
            _initSetting();
          }
          final rows = HarmonyStyle.enabled(context)
              ? _groupedSettings
              : settings;
          return HarmonySettingsList(
            sectionBuilder: (index) => rows[index].section,
            key: ValueKey(widget.settingType),
            padding: EdgeInsets.only(
              left: showAppBar ? padding.left : 0,
              right: showAppBar ? padding.right : 0,
              bottom: padding.bottom + 100,
            ),
            itemCount: rows.length,
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey(rows[index].effectiveTitle),
              child: rows[index].widget,
            ),
          );
        },
      ),
    );
  }
}
