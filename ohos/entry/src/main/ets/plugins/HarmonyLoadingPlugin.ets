import { common } from '@kit.AbilityKit';
import { FlutterPlugin, FlutterPluginBinding, PlatformView, PlatformViewFactory,
  StandardMessageCodec, Any } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';

@Builder
function loadingBuilder(params: Params) {
  LoadingProgress()
    .width('100%').height('100%')
    .color((params.platformView as HarmonyLoadingView).color)
    .enableLoading((params.platformView as HarmonyLoadingView).animate)
    .hitTestBehavior(HitTestMode.None)
}

class HarmonyLoadingView extends PlatformView {
  color: number;
  animate: boolean;
  constructor(color: number, animate: boolean) {
    super();
    this.color = color;
    this.animate = animate;
  }
  getView(): WrappedBuilder<[Params]> { return new WrappedBuilder(loadingBuilder); }
  dispose(): void {}
}

class HarmonyLoadingFactory extends PlatformViewFactory {
  constructor() { super(StandardMessageCodec.INSTANCE); }
  create(_context: common.Context, _viewId: number, args: Any): PlatformView {
    const values: Map<string, Object> = args as Map<string, Object>;
    return new HarmonyLoadingView(values.get('color') as number, values.get('animate') as boolean);
  }
}

export default class HarmonyLoadingPlugin implements FlutterPlugin {
  getUniqueClassName(): string { return 'HarmonyLoadingPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    binding.getPlatformViewRegistry().registerViewFactory('piliplus/native-loading', new HarmonyLoadingFactory());
  }
  onDetachedFromEngine(_binding: FlutterPluginBinding): void {}
}
