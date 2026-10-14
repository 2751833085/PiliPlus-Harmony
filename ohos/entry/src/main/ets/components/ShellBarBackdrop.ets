/// One native material shared by the home header and the fixed navigation bar.
/// No bitmap capture, per-frame color extraction or Flutter backdrop filter.
@Component
export struct ShellBarBackdrop {
  @Prop materialEnabled: boolean = true;
  @Prop inverted: boolean = false;

  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.navigation_bar_background'))
      .linearGradient({
        direction: this.inverted ? GradientDirection.Top : GradientDirection.Bottom,
        colors: this.materialEnabled ? [
          [$r('app.color.top_bar_mask_start'), 0],
          [$r('app.color.top_bar_mask_mid'), 0.8],
          [$r('app.color.top_bar_mask_end'), 0.95],
          [$r('app.color.top_bar_mask_end'), 1]
        ] : [[Color.Transparent, 0], [Color.Transparent, 1]]
      })
      .backgroundBlurStyle(this.materialEnabled ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
  }
}
