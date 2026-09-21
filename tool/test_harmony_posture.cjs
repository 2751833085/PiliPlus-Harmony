// Tests the actual ArkTS service with deterministic platform callbacks.
// ArkTS syntax/API correctness is checked separately by Hvigor assembleHap.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const home = process.env.HARMONY_COMMAND_LINE_TOOLS_HOME;
if (!home) throw new Error('Set HARMONY_COMMAND_LINE_TOOLS_HOME to the SDK command-line-tools directory');
const ts = require(path.join(home, 'hvigor/hvigor/node_modules/typescript'));
const source = fs.readFileSync(path.join(__dirname, '../ohos/entry/src/main/ets/plugins/SystemPosture.ets'), 'utf8');
const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;

function fixture({ unsupported = false, foldable = true, initialStatus = 2 } = {}) {
  let status = initialStatus;
  let timerId = 0;
  const timers = new Map();
  const displayListeners = new Map();
  const motionListeners = new Map();
  const messages = [];
  const display = {
    FoldStatus: { FOLD_STATUS_UNKNOWN: 0, FOLD_STATUS_FOLDED: 2 },
    isFoldable: () => foldable,
    getFoldStatus: () => status,
    on: (event, cb) => displayListeners.set(event, cb),
    off: (event, cb) => { assert.equal(displayListeners.get(event), cb); displayListeners.delete(event); },
  };
  const motion = {
    HoldingHandStatus: { LEFT_HAND_HELD: 1, RIGHT_HAND_HELD: 2 },
    on: (event, cb) => { if (unsupported) throw new Error('801'); motionListeners.set(event, cb); },
    off: (event, cb) => { assert.equal(motionListeners.get(event), cb); motionListeners.delete(event); },
  };
  const exports = {};
  vm.runInNewContext(code, {
    exports,
    require: name => {
      if (name === '@ohos.display') return { default: display };
      if (name === '@kit.MultimodalAwarenessKit') return { motion };
      throw new Error(`Unexpected import ${name}`);
    },
    setTimeout: fn => { timers.set(++timerId, fn); return timerId; },
    clearTimeout: id => timers.delete(id),
  });
  const service = new exports.SystemPosture({ invokeMethod: (method, args) => messages.push({ method, ...args }) });
  const flush = () => { const pending = [...timers.values()]; timers.clear(); pending.forEach(fn => fn()); };
  return {
    service, messages, timers, displayListeners, motionListeners, flush,
    hand: status => motionListeners.get('holdingHandChanged')?.(status),
    fold: next => { status = next; displayListeners.get('foldStatusChange')?.(status); },
  };
}

{
  const f = fixture();
  f.service.start();
  assert.equal(f.motionListeners.size, 0, 'grip must be opt-in');
  assert.equal(f.displayListeners.size, 3);
  f.service.setHandEnabled(true);
  f.hand(1); f.flush();
  assert.equal(f.messages.at(-1).side, 'left');
  f.hand(2); f.hand(1); f.flush();
  assert.equal(f.messages.at(-1).side, 'left', 'stale pending hand sample must be cancelled');
  f.hand(2); f.hand(16); f.flush();
  assert.equal(f.messages.at(-1).side, 'left', 'unknown sample must not move controls');
  f.hand(2); f.flush();
  assert.equal(f.messages.at(-1).side, 'right');
  f.fold(11);
  assert.equal(f.messages.at(-1).expanded, true, 'tri-fold must clear phone orientation before viewport changes');
  f.flush();
  f.fold(2);
  assert.equal(f.messages.at(-1).expanded, false);
  f.service.stop();
  assert.equal(f.motionListeners.size + f.displayListeners.size + f.timers.size, 0, 'backgrounding removes callbacks and timers');
  f.service.start();
  assert.equal(f.motionListeners.size, 1);
  f.service.setHandEnabled(false);
  assert.equal(f.messages.at(-1).side, 'center');
  assert.equal(f.motionListeners.size, 0);
  f.service.stop();
}
{
  const f = fixture({ unsupported: true, foldable: false });
  f.service.start();
  f.service.setHandEnabled(true);
  assert.equal(f.messages.at(-1).available, false, 'unsupported hardware degrades without throwing');
  assert.equal(f.displayListeners.size, 0);
  f.service.stop();
}
{
  const f = fixture({ initialStatus: 11 });
  assert.equal(f.service.isExpanded(), true, 'cold start must read unfolded state before any event listener');
  f.service.start();
  f.fold(2);
  assert.equal(f.service.isExpanded(), false);
  f.service.stop();
}
console.log('SystemPosture: grip opt-in, debounce, fold transitions, lifecycle and unsupported-device checks passed.');
