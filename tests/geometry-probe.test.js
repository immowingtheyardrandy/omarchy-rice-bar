const test = require('node:test');
const assert = require('node:assert/strict');
const GeometryProbe = require('../GeometryProbe.js');
const RiceModel = require('../RiceModel.js');

function item(x, y, width, height, extra = {}) {
  return { width, height, visible: true, children: [], mapToItem: () => ({ x, y }), ...extra };
}
function slot(id, region, x, y, width, height, extra = {}) {
  return item(x, y, width, height, { moduleName: id, region, activeItem: item(x, y, width, height), ...extra });
}
function geometry(host, vertical = false) {
  return GeometryProbe.geometryForHost(host, 26, vertical, RiceModel.isSlotSized);
}

test('collects nested sibling slots with coordinates mapped to the supplied host', () => {
  const host = { children: [
    { children: [slot('omarchy.menu', 'left', 8, 0, 27, 26)] },
    { children: [slot('omarchy.clock', 'center', 680, 0, 70, 26)] },
    { children: [slot('io.github.jcarcinogen.rice-bar', 'right', 1380, 0, 27, 26)] }
  ] };
  const clock = host.children[1].children[0];
  clock.mapToItem = target => { assert.equal(target, host); return { x: 680, y: 0 }; };
  assert.deepEqual(geometry(host).map(s => [s.id, s.x]), [
    ['omarchy.menu', 8], ['omarchy.clock', 680], ['io.github.jcarcinogen.rice-bar', 1380]
  ]);
});

test('never reaches another window through parents or service properties', () => {
  const other = { children: [slot('other-monitor', 'center', 999, 0, 50, 26)] };
  const host = { parent: other, bar: other, children: [slot('own-monitor', 'center', 20, 0, 50, 26)] };
  assert.deepEqual(geometry(host).map(s => s.id), ['own-monitor']);
});

test('excludes hidden ancestors, hidden widgets, unloaded slots and paint children', () => {
  const host = { children: [
    { visible: false, children: [slot('hidden-parent', 'left', 0, 0, 27, 26)] },
    slot('hidden-item', 'left', 0, 0, 27, 26, { activeItem: { visible: false } }),
    slot('unloaded', 'left', 0, 0, 27, 26, { activeItem: null }),
    { objectName: 'rice-bar-chrome', children: [slot('paint', 'left', 0, 0, 27, 26)] },
    slot('visible', 'left', 0, 0, 27, 26)
  ] };
  assert.deepEqual(geometry(host).map(s => s.id), ['visible']);
});

test('rejects non-finite geometry and failed mappings instead of using local offsets', () => {
  const host = { children: [
    slot('zero', 'left', 0, 0, 0, 26),
    slot('infinite-size', 'left', 0, 0, Infinity, 26),
    slot('nan-position', 'left', NaN, 0, 27, 26),
    slot('unmapped', 'left', 0, 0, 27, 26, { mapToItem: () => { throw Error('detached'); } })
  ] };
  assert.deepEqual(geometry(host), []);
});

test('bounds cyclic and oversized visual trees', () => {
  const cyclic = { children: [] };
  cyclic.children.push(cyclic);
  assert.deepEqual(geometry(cyclic), []);
  const huge = { children: Array.from({ length: 2000 }, () => slot('widget', 'left', 0, 0, 27, 26)) };
  assert.equal(geometry(huge).length, 511);
});

test('does not mistake scalar APIs or plain widget items for host slots', () => {
  assert.deepEqual(geometry(null), []);
  assert.deepEqual(geometry({ barHidden: false, barSize: 26, position: 'top' }), []);
  assert.deepEqual(geometry({ children: [item(0, 0, 27, 26, { moduleName: 'widget' })] }), []);
});

test('samples tray icons along the correct cross-axis for horizontal and vertical bars', () => {
  const horizontalTray = slot('omarchy.tray', 'right', 100, 0, 81, 26);
  horizontalTray.activeItem.children = [item(100, 0, 27, 26), item(127, 0, 27, 26), item(154, 40, 27, 26)];
  const horizontal = geometry({ children: [horizontalTray] })[0];
  assert.deepEqual(horizontal.leaves.map(s => s.x), [100, 127]);

  const verticalTray = slot('omarchy.tray', 'right', 0, 100, 26, 81);
  verticalTray.activeItem.children = [item(0, 100, 26, 27), item(0, 127, 26, 27), item(40, 154, 26, 27)];
  const vertical = geometry({ children: [verticalTray] }, true)[0];
  assert.deepEqual(vertical.leaves.map(s => s.y), [100, 127]);
});
