import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';

class AiConclusionData {
  final AiConclusionResult? modelResult;
  final int? code;
  final int? resultType;

  const AiConclusionData({this.modelResult, this.code, this.resultType});

  bool get hasContent =>
      modelResult?.summary?.trim().isNotEmpty == true ||
      modelResult?.outline?.isNotEmpty == true;

  // Prefer delivered content even if the service status has not caught up.
  bool get isGenerating => code == 1 && !hasContent;

  String get unavailableMessage => switch (code) {
    -1 => '当前视频暂不支持 AI 视频总结',
    1 => '等待 AI 总结超时，请稍后重试',
    _ => '哔哩哔哩暂未提供此视频的 AI 总结',
  };

  factory AiConclusionData.fromJson(Map<String, dynamic> json) {
    final model = json['model_result'];
    return AiConclusionData(
      code: (json['code'] as num?)?.toInt(),
      resultType: (model is Map ? model['result_type'] as num? : null)?.toInt(),
      modelResult: model is Map<String, dynamic>
          ? AiConclusionResult.fromJson(model)
          : null,
    );
  }
}
