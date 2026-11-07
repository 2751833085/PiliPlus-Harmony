import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/route_settled_autofocus.dart';
import 'package:PiliPlus/pages/search/widgets/search_split_sliver.dart';
import 'dart:convert';

import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/disabled_icon.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_keyword_section.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/em.dart' show Em;
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _tag = Utils.generateRandomString(6);
  late final SSearchController _searchController;
  late ThemeData theme;
  late bool isPortrait;
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    _searchController = Get.put(SSearchController(_tag), tag: _tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
    padding = MediaQuery.viewPaddingOf(context);
    isPortrait = MediaQuery.sizeOf(context).isPortrait;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final trending = _searchController.enableTrending
        ? _keywordSection(isTrending: true, wide: wide)
        : null;
    final rcmd = _searchController.enableSearchRcmd
        ? _keywordSection(isTrending: false, wide: wide)
        : null;

    return SimpleScaffold(
      appBar: _buildAppBar,
      body: Padding(
        padding: EdgeInsets.only(
          left: padding.left + (wide ? 68 : 0),
          right: padding.right + (wide ? 68 : 0),
        ),
        child: CustomScrollView(
          slivers: [
            if (_searchController.searchSuggestion) _buildSearchSuggest(),
            if (wide)
              SearchSplitSliver(
                left: SliverMainAxisGroup(slivers: [?trending, ?rcmd]),
                right: _buildHistory,
              )
            else ...[
              ?trending,
              _buildHistory,
              ?rcmd,
            ],
            SliverPadding(padding: .only(bottom: padding.bottom)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget get _buildAppBar => AppBar(
    shape: Border(
      bottom: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.08),
        width: 1,
      ),
    ),
    actions: [
      Obx(
        () => _searchController.showUidBtn.value
            ? IconButton(
                tooltip: 'UID搜索用户',
                icon: const Icon(Icons.person_outline, size: 22),
                onPressed: () => Get.toNamed(
                  '/member?mid=${_searchController.controller.text}',
                ),
              )
            : const SizedBox.shrink(),
      ),
      IconButton(
        tooltip: '清空',
        icon: const Icon(Icons.clear, size: 22),
        onPressed: _searchController.onClear,
      ),
      IconButton(
        tooltip: '搜索',
        onPressed: _searchController.submit,
        icon: const Icon(Icons.search, size: 22),
      ),
      const SizedBox(width: 10),
    ],
    title: RouteSettledAutofocus(
      enabled: HarmonyStyle.enabled(context),
      focusNode: _searchController.searchFocusNode,
      child: TextField(
        autofocus: !HarmonyStyle.enabled(context),
        focusNode: _searchController.searchFocusNode,
        controller: _searchController.controller,
        textInputAction: TextInputAction.search,
        onChanged: _searchController.onChange,
        decoration: InputDecoration(
          visualDensity: .standard,
          hintText: _searchController.hintText ?? '搜索',
          border: InputBorder.none,
        ),
        onSubmitted: (value) => _searchController.submit(),
      ),
    ),
  );

  Widget _buildSearchSuggest() {
    return Obx(() {
      final list = _searchController.searchSuggestList;
      return list.isNotEmpty &&
              list.first.term != null &&
              _searchController.controller.text != ''
          ? SliverList.list(
              children: list
                  .map(
                    (item) => InkWell(
                      borderRadius: const .all(.circular(4)),
                      onTap: () => _searchController.onClickKeyword(
                        item.term!,
                        clearSuggest: false,
                      ),
                      child: Padding(
                        padding: const .only(left: 20, top: 9, bottom: 9),
                        child: Text.rich(
                          TextSpan(
                            children: Em.regTitle(item.textRich)
                                .map(
                                  (e) => TextSpan(
                                    text: e.text,
                                    style: e.isEm
                                        ? TextStyle(
                                            fontWeight: .bold,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          : const SliverToBoxAdapter();
    });
  }

  Widget _keywordSection({required bool isTrending, required bool wide}) =>
      SearchKeywordSection(
        controller: _searchController.keywords,
        isTrending: isTrending,
        padding: EdgeInsets.fromLTRB(
          wide ? 0 : 10,
          !isTrending && (isPortrait || _searchController.enableTrending)
              ? 4
              : 25,
          4,
          25,
        ),
        onClick: _searchController.onClickKeyword,
      );

  late final mainAxisExtent = 16 + MediaQuery.textScalerOf(context).scale(14);
  Widget get _buildHistory {
    return Obx(
      () {
        final list = _searchController.historyList;
        if (list.isEmpty) {
          return const SliverToBoxAdapter();
        }
        final secondary = theme.colorScheme.secondary;
        return SliverPadding(
          padding: .fromLTRB(
            10,
            !isPortrait
                ? 25
                : _searchController.enableTrending
                ? 0
                : 6,
            6,
            25,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: const .fromLTRB(6, 0, 6, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        '搜索历史',
                        strutStyle: const StrutStyle(leading: 0, height: 1),
                        style: theme.textTheme.titleMedium!.copyWith(
                          height: 1,
                          fontWeight: .bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _recordBtn,
                      _exportBtn,
                      const Spacer(),
                      TextButton.icon(
                        style: const ButtonStyle(
                          visualDensity: .compact,
                          tapTargetSize: .shrinkWrap,
                          padding: WidgetStatePropertyAll(
                            .symmetric(horizontal: 10),
                          ),
                        ),
                        onPressed: _searchController.onClearHistory,
                        icon: Icon(
                          Icons.clear_all_outlined,
                          size: 18,
                          color: secondary,
                        ),
                        label: Text(
                          '清空',
                          style: TextStyle(height: 1, color: secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverFixedWrap(
                mainAxisExtent: mainAxisExtent,
                spacing: 8,
                runSpacing: 8,
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  childCount: list.length,
                  (context, index) => SearchText(
                    text: list[index],
                    bgColor: Colors.transparent,
                    onTap: _searchController.onClickKeyword,
                    onLongPress: _searchController.onLongSelect,
                    height: 1,
                    maxLines: 1,
                    fontSize: 14,
                    overflow: .ellipsis,
                    padding: const .fromLTRB(11, 8, 11, 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget get _recordBtn => Obx(
    () {
      bool enable = _searchController.recordSearchHistory.value;
      return IconButton(
        iconSize: 22,
        tooltip: enable ? '记录搜索' : '无痕搜索',
        icon: DisabledIcon(
          disable: !enable,
          child: Icon(
            Icons.history,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        style: const ButtonStyle(
          visualDensity: .comfortable,
          tapTargetSize: .shrinkWrap,
          padding: WidgetStatePropertyAll(.zero),
        ),
        onPressed: () {
          enable = !enable;
          _searchController.recordSearchHistory.value = enable;
          GStorage.setting.put(
            SettingBoxKey.recordSearchHistory,
            enable,
          );
        },
      );
    },
  );

  Widget get _exportBtn => IconButton(
    iconSize: 22,
    tooltip: '导入/导出历史记录',
    icon: Icon(
      Icons.import_export_outlined,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    ),
    style: const ButtonStyle(
      visualDensity: .comfortable,
      tapTargetSize: .shrinkWrap,
      padding: WidgetStatePropertyAll(.zero),
    ),
    onPressed: () => showImportExportDialog<List>(
      context,
      title: '历史记录',
      localFileName: () => 'search',
      onExport: () => jsonEncode(_searchController.historyList),
      onImport: (json) {
        final list = List<String>.from(json);
        _searchController.historyList.value = list;
        GStorage.historyWord.put('cacheList', list);
      },
    ),
  );
}
