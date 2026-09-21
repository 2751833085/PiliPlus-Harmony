import display from '@ohos.display';
import { motion } from '@kit.MultimodalAwarenessKit';
import { MethodChannel } from '@ohos/flutter_ohos';

/** System callbacks live only while the ability is in the foreground. */
export class SystemPosture {
  private active: boolean = false;
  private handEnabled: boolean = false;
  private handListening: boolean = false;
  private foldListening: boolean = false;
  private modeListening: boolean = false;
  private angleListening: boolean = false;
  private handTimer: number = -1;
  private foldTimer: number = -1;
  private angles: number[] = [];
  private side: string = 'center';

  private channel: MethodChannel;
  constructor(channel: MethodChannel) { this.channel = channel; }

  private holdingChanged = (status: motion.HoldingHandStatus): void => {
    // Uncertain and two-handed samples keep the last stable placement.
    if (this.handTimer >= 0) clearTimeout(this.handTimer);
    this.handTimer = -1;
    if (status !== motion.HoldingHandStatus.LEFT_HAND_HELD &&
      status !== motion.HoldingHandStatus.RIGHT_HAND_HELD) return;
    const side = status === motion.HoldingHandStatus.LEFT_HAND_HELD ? 'left' : 'right';
    if (side === this.side) return;
    if (this.handTimer >= 0) clearTimeout(this.handTimer);
    this.handTimer = setTimeout(() => {
      this.handTimer = -1;
      this.side = side;
      this.channel.invokeMethod('onHoldingHandChanged', { side: side, available: true });
    }, 180);
  };

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
  isExpanded(): boolean {
    try {
      const status = display.getFoldStatus();
      return status !== display.FoldStatus.FOLD_STATUS_UNKNOWN &&
        status !== display.FoldStatus.FOLD_STATUS_FOLDED;
    } catch (_) { return false; }
  }

  setHandEnabled(enabled: boolean): void {
    this.handEnabled = enabled;
    if (!enabled) {
      this.stopHand();
      this.side = 'center';
      this.channel.invokeMethod('onHoldingHandChanged', { side: 'center', available: false });
    } else if (this.active) this.startHand();
  }

  private startHand(): void {
    if (this.handListening) return;
    try {
      motion.on('holdingHandChanged', this.holdingChanged);
      this.handListening = true;
      this.channel.invokeMethod('onHoldingHandChanged', { side: this.side, available: true });
    } catch (_) {
      this.channel.invokeMethod('onHoldingHandChanged', { side: 'center', available: false });
    }
  }

  private stopHand(): void {
    if (this.handTimer >= 0) clearTimeout(this.handTimer);
    this.handTimer = -1;
    if (this.handListening) {
      try { motion.off('holdingHandChanged', this.holdingChanged); } catch (_) {}
      this.handListening = false;
    }
  }

  start(): void {
    if (this.active) return;
    this.active = true;
    if (this.handEnabled) this.startHand();
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
    this.stopHand();
    if (this.foldTimer >= 0) clearTimeout(this.foldTimer);
    this.foldTimer = -1;
    if (this.foldListening) { try { display.off('foldStatusChange', this.foldChanged); } catch (_) {} }
    if (this.modeListening) { try { display.off('foldDisplayModeChange', this.modeChanged); } catch (_) {} }
    if (this.angleListening) { try { display.off('foldAngleChange', this.angleChanged); } catch (_) {} }
    this.foldListening = this.modeListening = this.angleListening = false;
  }
}
