import 'package:PiliPlus/models/common/search/user_search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/filter_panel.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchUserController
    extends SearchPanelController<SearchUserData, SearchUserItemModel> {
  SearchUserController({
    required super.keyword,
    required super.searchType,
    required super.tag,
  });

  @override
  void onInit() {
    super.onInit();
    userType = UserType.all.obs;
    userOrderType = UserOrderType.def.obs;
  }

  void onShowFilterDialog(BuildContext context) {
    showSearchFilterPanel(
      context,
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: searchFilterPadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text('用户粉丝数及等级排序顺序', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserOrderType.values.map(
                  (e) {
                    final isCurr = e == userOrderType!.value;
                    return SearchText(
                      text: e.label,
                      onTap: (_) {
                        userOrderType!.value = e;
                        order = e.order;
                        onSortSearch(label: e.label);
                      },
                      bgColor: isCurr
                          ? theme.colorScheme.secondaryContainer
                          : null,
                      textColor: isCurr
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 20),
              const Text('用户分类', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserType.values.map(
                  (e) {
                    final isCurr = e == userType!.value;
                    return SearchText(
                      text: e.label,
                      onTap: (_) {
                        userType!.value = e;
                        onSortSearch(label: e.label);
                      },
                      bgColor: isCurr
                          ? theme.colorScheme.secondaryContainer
                          : null,
                      textColor: isCurr
                          ? theme.colorScheme.onSecondaryContainer
                          : null,
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
