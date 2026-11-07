import display from '@ohos.display';
import { MethodChannel } from '@ohos/flutter_ohos';

/** System callbacks live only while the ability is in the foreground. */
export class SystemPosture {
  private active: boolean = false;
  private foldListening: boolean = false;
  private modeListening: boolean = false;
  private angleListening: boolean = false;
  private foldTimer: number = -1;
  private angles: number[] = [];

  private channel: MethodChannel;
  constructor(channel: MethodChannel) { this.channel = channel; }

  private foldChanged = (_status: display.FoldStatus): void => { this.pushFold(); this.scheduleFold(); };
  private modeChanged = (_mode: display.FoldDisplayMode): void => { this.scheduleFold(); };
  private angleChanged = (angles: number[]): void => {
    // Only notify changes across a usable unfolded angle; don't rotate per sample.
    const before = this.angles.some((angle: number) => angle >= 150);
    this.angles = angles;
    if (before !== angles.some((angle: number) => angle >= 150)) this.scheduleFold();
  };

  private scheduleFold(): void {
    if (this.foldTimer >= 0) clearTimeout(this.foldTimer);
    this.foldTimer = setTimeout(() => { this.foldTimer = -1; this.pushFold(); }, 300);
  }

  private pushFold(): void {
    if (!this.active) return;
    try {
      const status = display.getFoldStatus();
      if (status === display.FoldStatus.FOLD_STATUS_UNKNOWN) return;
      // A tri-fold reports additional states (11, 12, 13, 21, 22, 23).
      const expanded = status !== display.FoldStatus.FOLD_STATUS_FOLDED;
      this.channel.invokeMethod('onFoldPostureChanged', { expanded: expanded, status: status });
    } catch (_) {}
  }

  // The first event can precede Dart handler registration on a cold start.
  // Flutter pulls a fresh snapshot before laying out its first page.
  isFoldable(): boolean {
    try { return display.isFoldable(); } catch (_) { return false; }
  }

  isExpanded(): boolean {
    try {
      const status = display.getFoldStatus();
      return status !== display.FoldStatus.FOLD_STATUS_UNKNOWN &&
        status !== display.FoldStatus.FOLD_STATUS_FOLDED;
    } catch (_) { return false; }
  }

  start(): void {
    if (this.active) return;
    this.active = true;
    try {
      if (!display.isFoldable()) return;
      display.on('foldStatusChange', this.foldChanged);
      this.foldListening = true;
      display.on('foldDisplayModeChange', this.modeChanged);
      this.modeListening = true;
      display.on('foldAngleChange', this.angleChanged);
      this.angleListening = true;
    } catch (_) {}
    this.pushFold();
  }

  stop(): void {
    this.active = false;
    if (this.foldTimer >= 0) clearTimeout(this.foldTimer);
    this.foldTimer = -1;
    if (this.foldListening) { try { display.off('foldStatusChange', this.foldChanged); } catch (_) {} }
    if (this.modeListening) { try { display.off('foldDisplayModeChange', this.modeChanged); } catch (_) {} }
    if (this.angleListening) { try { display.off('foldAngleChange', this.angleChanged); } catch (_) {} }
    this.foldListening = this.modeListening = this.angleListening = false;
  }
}
