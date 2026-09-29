import { common } from '@kit.AbilityKit';
import { FlutterPlugin, FlutterPluginBinding, PlatformView, PlatformViewFactory,
  StandardMessageCodec, Any, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';

@Observed
class LoadingAppearance {
  opacity: number;
  constructor(opacity: number) { this.opacity = opacity; }
}

@Component
struct NativeLoadingSurface {
  @ObjectLink appearance: LoadingAppearance;
  color: number = 0;
  animate: boolean = true;
  build() {
    LoadingProgress()
      .width('100%').height('100%')
      .color(this.color)
      .enableLoading(this.animate)
      .opacity(this.appearance.opacity)
      .hitTestBehavior(HitTestMode.None)
  }
}

@Builder
function loadingBuilder(params: Params) {
  NativeLoadingSurface({
    appearance: (params.platformView as HarmonyLoadingView).appearance,
    color: (params.platformView as HarmonyLoadingView).color,
    animate: (params.platformView as HarmonyLoadingView).animate
  })
}

class HarmonyLoadingView extends PlatformView {
  color: number;
  animate: boolean;
  appearance: LoadingAppearance;
  private channel: MethodChannel;
  constructor(binding: FlutterPluginBinding, viewId: number, color: number, animate: boolean, opacity: number) {
    super();
    this.color = color;
    this.animate = animate;
    this.appearance = new LoadingAppearance(opacity);
    this.channel = new MethodChannel(binding.getBinaryMessenger(), `piliplus/native-loading/${viewId}`);
    this.channel.setMethodCallHandler(this);
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'setOpacity') {
      const value = call.args as number;
      if (typeof value === 'number' && Number.isFinite(value)) {
        this.appearance.opacity = Math.max(0, Math.min(1, value));
      }
      result.success(null);
    } else {
      result.notImplemented();
    }
  }
  getView(): WrappedBuilder<[Params]> { return new WrappedBuilder(loadingBuilder); }
  dispose(): void { this.channel.setMethodCallHandler(null); }
}

class HarmonyLoadingFactory extends PlatformViewFactory {
  private binding: FlutterPluginBinding;
  constructor(binding: FlutterPluginBinding) {
    super(StandardMessageCodec.INSTANCE);
    this.binding = binding;
  }
  create(_context: common.Context, viewId: number, args: Any): PlatformView {
    const values: Map<string, Object> = args as Map<string, Object>;
    const opacity = values.get('opacity') as number;
    return new HarmonyLoadingView(this.binding, viewId, values.get('color') as number,
      values.get('animate') as boolean, Number.isFinite(opacity) ? Math.max(0, Math.min(1, opacity)) : 1);
  }
}

export default class HarmonyLoadingPlugin implements FlutterPlugin {
  getUniqueClassName(): string { return 'HarmonyLoadingPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    binding.getPlatformViewRegistry().registerViewFactory('piliplus/native-loading', new HarmonyLoadingFactory(binding));
  }
  onDetachedFromEngine(_binding: FlutterPluginBinding): void {}
}
