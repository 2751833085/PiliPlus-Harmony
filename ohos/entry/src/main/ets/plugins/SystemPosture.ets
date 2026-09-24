import display from '@ohos.display';
import { BusinessError } from '@kit.BasicServicesKit';
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
  private pendingSide: string = '';
  private hasSample: boolean = false;

  private channel: MethodChannel;
  constructor(channel: MethodChannel) { this.channel = channel; }

  private holdingChanged = (status: motion.HoldingHandStatus): void => {
    if (!this.active || !this.handEnabled) return;
    let side: string;
    switch (status) {
      case motion.HoldingHandStatus.LEFT_HAND_HELD: side = 'left'; break;
      case motion.HoldingHandStatus.RIGHT_HAND_HELD: side = 'right'; break;
      case motion.HoldingHandStatus.BOTH_HANDS_HELD: side = 'center'; break;
      default:
        this.cancelPendingHand();
        return;
    }
    // Repeated samples must not postpone an already pending stable transition.
    if (side === this.pendingSide) return;
    this.cancelPendingHand();
    if (this.hasSample && side === this.side) return;
    this.pendingSide = side;
    this.handTimer = setTimeout(() => {
      this.handTimer = -1;
      this.pendingSide = '';
      if (!this.active || !this.handEnabled) return;
      this.side = side;
      this.hasSample = true;
      this.publishHand(true);
    }, 180);
  };

  private cancelPendingHand(): void {
    if (this.handTimer >= 0) clearTimeout(this.handTimer);
    this.handTimer = -1;
    this.pendingSide = '';
  }

  private publishHand(available: boolean, state: string = 'waiting'): void {
    AppStorage.setOrCreate('systemHoldingSide', available ? this.side : 'center');
    AppStorage.setOrCreate('systemHoldingAvailable', available);
    this.channel.invokeMethod('onHoldingHandChanged', {
      side: available ? this.side : 'center', available: available,
      state: available ? this.side : state
    });
  }

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
      this.publishHand(false, 'disabled');
    } else if (this.active) this.startHand();
  }

  private startHand(): void {
    if (this.handListening) return;
    try {
      motion.on('holdingHandChanged', this.holdingChanged);
      this.handListening = true;
      this.hasSample = false;
      this.publishHand(false);
    } catch (error) {
      const code = (error as BusinessError).code;
      this.publishHand(false, code === 801 ? 'unsupported' : code === 201 ? 'denied' : 'unavailable');
    }
  }

  private stopHand(): void {
    this.cancelPendingHand();
    this.hasSample = false;
    this.publishHand(false);
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
