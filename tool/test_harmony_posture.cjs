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

function fixture({ foldable = true, initialStatus = 2 } = {}) {
  let status = initialStatus;
  let timerId = 0;
  const timers = new Map();
  const displayListeners = new Map();
  const messages = [];
  const display = {
    FoldStatus: { FOLD_STATUS_UNKNOWN: 0, FOLD_STATUS_FOLDED: 2 },
    isFoldable: () => foldable,
    getFoldStatus: () => status,
    on: (event, cb) => displayListeners.set(event, cb),
    off: (event, cb) => { assert.equal(displayListeners.get(event), cb); displayListeners.delete(event); },
  };
  const exports = {};
  vm.runInNewContext(code, {
    exports,
    require: name => {
      if (name === '@ohos.display') return { default: display };
      throw new Error(`Unexpected import ${name}`);
    },
    setTimeout: fn => { timers.set(++timerId, fn); return timerId; },
    clearTimeout: id => timers.delete(id),
  });
  const service = new exports.SystemPosture({ invokeMethod: (method, args) => messages.push({ method, ...args }) });
  const flush = () => { const pending = [...timers.values()]; timers.clear(); pending.forEach(fn => fn()); };
  return {
    service, messages, timers, displayListeners, flush,
    fold: next => { status = next; displayListeners.get('foldStatusChange')?.(status); },
  };
}

{
  const f = fixture();
  assert.equal(f.service.isFoldable(), true);
  f.service.start();
  assert.equal(f.displayListeners.size, 3);
  f.fold(11);
  assert.equal(f.messages.at(-1).expanded, true, 'tri-fold must clear phone orientation before viewport changes');
  f.flush();
  f.fold(0); f.flush();
  assert.equal(f.messages.at(-1).expanded, true, 'unknown fold samples must not force an exit');
  f.fold(2);
  assert.equal(f.messages.at(-1).expanded, false);
  f.service.stop();
  assert.equal(f.displayListeners.size + f.timers.size, 0, 'backgrounding removes callbacks and timers');
  f.service.start();
  assert.equal(f.displayListeners.size, 3, 'foregrounding restores fold callbacks');
  assert.equal(f.messages.at(-1).expanded, false);
  f.service.stop();
}
{
  const f = fixture({ foldable: false });
  f.service.start();
  assert.equal(f.displayListeners.size, 0);
  assert.equal(f.service.isFoldable(), false, 'non-fold hardware cannot enable fold-only settings');
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
console.log('SystemPosture: fold transitions, lifecycle and non-foldable device checks passed.');
