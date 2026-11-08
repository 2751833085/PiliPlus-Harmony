import 'dart:async' show FutureOr;
import 'dart:convert' show utf8, jsonDecode;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:file_picker_ohos/file_picker_ohos.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/base16/github.dart';
import 'package:re_highlight/styles/github-dark.dart';

Future<void> exportToClipBoard({
  required ValueGetter<String> onExport,
}) async {
  try {
    await Utils.copyText(onExport(), needToast: false);
    SmartDialog.showToast('已复制');
  } catch (_) {
    SmartDialog.showToast('导出失败，请重试');
  }
}

Future<void> exportToLocalFile({
  required ValueGetter<String> onExport,
  required ValueGetter<String> localFileName,
}) async {
  try {
    await StorageUtils.saveBytes2File(
      name:
          'piliplus_${localFileName()}_'
          '${DateFormatUtils.only0_9.format(DateTime.now())}.json',
      bytes: utf8.encode(onExport()),
      allowedExtensions: const ['json'],
    );
  } catch (_) {
    SmartDialog.showToast('导出失败，请重试');
  }
}

String _errorMessage(String message, Object error, bool sensitive) =>
    sensitive ? '$message，请检查备份内容或重试' : '$message：$error';

Future<void> importFromClipBoard<T>(
  BuildContext context, {
  required String title,
  required ValueGetter<String> onExport,
  required FutureOr<void> Function(T json) onImport,
  bool showConfirmDialog = true,
  bool sensitive = false,
}) async {
  final ClipboardData? data;
  try {
    data = await Clipboard.getData('text/plain');
  } catch (_) {
    if (context.mounted) SmartDialog.showToast('无法读取剪贴板');
    return;
  }
  if (data?.text case final text? when (text.isNotEmpty)) {
    if (!context.mounted) return;
    final T json;
    try {
      json = jsonDecode(text);
    } catch (e) {
      SmartDialog.showToast(_errorMessage('解析 JSON 失败', e, sensitive));
      return;
    }
    bool? executeImport;
    if (showConfirmDialog && sensitive) {
      executeImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导入剪贴板中的$title？'),
          content: const Text('备份可能含有凭据，请确认来源可信。'),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('取消')),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else if (showConfirmDialog) {
      final highlight = Highlight()..registerLanguage('json', langJson);
      final result = highlight.highlight(
        code: Utils.jsonEncoder.convert(json),
        language: 'json',
      );
      late TextSpanRenderer renderer;
      bool? isDarkMode;
      executeImport = await showDialog<bool>(
        context: context,
        builder: (context) {
          final colorScheme = ColorScheme.of(context);
          final isDark = colorScheme.isDark;
          if (isDark != isDarkMode) {
            isDarkMode = isDark;
            renderer = TextSpanRenderer(
              null,
              isDark ? githubDarkTheme : githubTheme,
            );
            result.render(renderer);
          }
          return AlertDialog(
            title: Text('是否导入如下$title？'),
            content: SingleChildScrollView(
              child: Text.rich(renderer.span!),
            ),
            actions: [
              TextButton(
                onPressed: Get.back,
                child: Text('取消', style: TextStyle(color: colorScheme.outline)),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } else {
      executeImport = true;
    }
    if (context.mounted && executeImport == true) {
      try {
        await onImport(json);
        if (context.mounted) SmartDialog.showToast('导入成功');
      } catch (e) {
        if (context.mounted) {
          SmartDialog.showToast(_errorMessage('导入失败', e, sensitive));
        }
      }
    }
  } else {
    SmartDialog.showToast('剪贴板无数据');
    return;
  }
}

Future<void> importFromLocalFile<T>({
  required FutureOr<void> Function(T json) onImport,
  BuildContext? context,
  bool sensitive = false,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
    );
    if (result?.files.firstOrNull case final file?) {
      final data = await file.xFile.readAsString();
      if (context?.mounted == false) return;
      final T json = jsonDecode(data);
      await onImport(json);
      if (context?.mounted != false) SmartDialog.showToast('导入成功');
    }
  } catch (e) {
    if (context?.mounted != false) {
      SmartDialog.showToast(_errorMessage('导入失败', e, sensitive));
    }
  }
}

void importFromInput<T>(
  BuildContext context, {
  required String title,
  required FutureOr<void> Function(T json) onImport,
  bool sensitive = false,
}) {
  final key = GlobalKey<FormFieldState<String>>();
  late T json;
  String? forceErrorText;
  var importing = false;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('输入$title'),
      constraints: Style.dialogFixedConstraints,
      content: TextFormField(
        key: key,
        minLines: 4,
        maxLines: 12,
        autofocus: true,
        autocorrect: !sensitive,
        enableSuggestions: !sensitive,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (forceErrorText != null) return forceErrorText;
          try {
            json = jsonDecode(value!) as T;
            return null;
          } catch (e) {
            return _errorMessage('解析 JSON 失败', e, sensitive);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(
              color: ColorScheme.of(context).outline,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (importing || key.currentState?.validate() != true) return;
            importing = true;
            try {
              await onImport(json);
              if (!context.mounted ||
                  ModalRoute.of(context)?.isCurrent != true) {
                return;
              }
              Navigator.of(context).pop();
              SmartDialog.showToast('导入成功');
            } catch (e) {
              forceErrorText = _errorMessage('导入失败', e, sensitive);
              key.currentState?.validate();
              forceErrorText = null;
            } finally {
              importing = false;
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

Future<void> showImportExportDialog<T>(
  BuildContext context, {
  required String title,
  required ValueGetter<String> onExport,
  required FutureOr<void> Function(T json) onImport,
  required ValueGetter<String> localFileName,
  String? description,
  bool sensitive = false,
}) => showDialog(
  context: context,
  builder: (dialogContext) {
    const style = TextStyle(fontSize: 15);
    return SimpleDialog(
      clipBehavior: .hardEdge,
      title: Text('导入/导出$title'),
      children: [
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              description,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ),
        DialogOption(
          child: const Text('导出至剪贴板', style: style),
          onPressed: () {
            Get.back();
            exportToClipBoard(onExport: onExport);
          },
        ),
        DialogOption(
          child: const Text('导出文件至本地', style: style),
          onPressed: () {
            Get.back();
            exportToLocalFile(onExport: onExport, localFileName: localFileName);
          },
        ),
        Divider(
          height: 1,
          color: ColorScheme.of(dialogContext).outline.withValues(alpha: 0.1),
        ),
        DialogOption(
          child: const Text('输入', style: style),
          onPressed: () {
            Get.back();
            importFromInput<T>(
              context,
              title: title,
              onImport: onImport,
              sensitive: sensitive,
            );
          },
        ),
        DialogOption(
          child: const Text('从剪贴板导入', style: style),
          onPressed: () {
            Get.back();
            importFromClipBoard<T>(
              context,
              title: title,
              onExport: onExport,
              onImport: onImport,
              sensitive: sensitive,
            );
          },
        ),
        DialogOption(
          child: const Text('从本地文件导入', style: style),
          onPressed: () {
            Get.back();
            importFromLocalFile<T>(
              context: context,
              onImport: onImport,
              sensitive: sensitive,
            );
          },
        ),
      ],
    );
  },
);
