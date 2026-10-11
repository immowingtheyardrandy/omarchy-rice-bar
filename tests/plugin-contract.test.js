const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function source(name) {
  return fs.readFileSync(path.join(root, name), 'utf8');
}

test('manifest declares a stock-bar overlay with selectable presets', () => {
  const manifest = JSON.parse(source('manifest.json'));
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.id, 'io.github.jcarcinogen.rice-bar');
  assert.deepEqual(manifest.kinds, ['service', 'bar-widget']);
  assert.equal(manifest.entryPoints.service, 'Service.qml');
  assert.equal(manifest.entryPoints.barWidget, 'BarWidget.qml');
  assert.equal(manifest.barWidget.defaultSection, 'right');
  assert.equal(manifest.barWidget.defaults.preset, 'islands');
  const preset = manifest.barWidget.schema.find(entry => entry.key === 'preset');
  assert.deepEqual(preset.options, [
    'Omarchy', 'Islands', 'Pills', 'Material', 'Outline',
    'Rail', 'Bracket', 'Glow', 'Powerline', 'Mono', 'Minimal'
  ]);
});

test('chrome stays in the stock window and never intercepts input', () => {
  const manifest = JSON.parse(source('manifest.json'));
  assert.equal(manifest.kinds.includes('bar'), false);
  const widget = source('BarWidget.qml');
  const chrome = source('RiceChrome.qml');
  assert.match(widget, /root\.QsWindow\.window/);
  assert.match(widget, /parent:\s*root\.chromeHost/);
  assert.match(chrome, /enabled:\s*false/);
  assert.doesNotMatch(chrome, /PanelWindow|MouseArea|TapHandler/);
});

test('only the scoped shell API is used for settings and IPC', () => {
  const service = source('Service.qml');
  assert.match(service, /RiceModel\.configFromShell\(shell\)/);
  assert.match(service, /shell\.updateEntryInline\(pluginId/);
  assert.match(service, /panelAction\("summon"\)/);
  assert.match(service, /panelAction\("hide"\)/);
  assert.match(service, /panelAction\("toggle"\)/);
  for (const name of ['Service.qml', 'BarWidget.qml', 'RiceChrome.qml', 'GeometryProbe.js']) {
    assert.doesNotMatch(source(name), /Process\s*\{|FileView\s*\{|mutateShellConfig|setRequestedTransparency|requestedTransparent\s*=|transparentForeground\s*=/, name);
  }
});

test('window transparency is temporary and restores the host binding', () => {
  const widget = source('BarWidget.qml');
  assert.match(widget, /Binding\s*\{[\s\S]*property:\s*"color"[\s\S]*Binding\.RestoreBindingOrValue/);
  assert.match(widget, /when:\s*chromeLoader\.item !== null && chromeLoader\.item\.visible/);
});

test('visible settings control participates in Rice Bar surface geometry', () => {
  const service = source('RiceChrome.qml');
  assert.doesNotMatch(service, /(?:pillRects|islandRects)\([^\n]*pluginId/);
});

test('settings control uses the rice-bowl glyph and never replaces Omarchy branding', () => {
  const rice = '\u{F07EA}';
  const widget = source('BarWidget.qml');
  const panel = source('RicePanel.qml');
  assert.match(widget, /BarIconButton/);
  assert.match(widget, new RegExp(rice));
  assert.match(panel, new RegExp(rice));
  assert.doesNotMatch(widget, /text:\s*["'](?:OMARCHY|Omarchy)["']/);
  assert.doesNotMatch(widget, /moduleName:\s*["']omarchy\./);
});

test('tray geometry is sampled from the widget window', () => {
  assert.match(source('BarWidget.qml'), /GeometryProbe\.geometryForHost\(chromeHost/);
  assert.match(source('GeometryProbe.js'), /omarchy\.tray/);
  assert.match(source('GeometryProbe.js'), /trayLeaves/);
});

test('all selectable presets are exposed by the panel and delegated to paint recipes', () => {
  const service = source('RiceChrome.qml');
  const panel = source('RicePanel.qml');
  assert.match(service, /RiceModel\.paintRecipe\(preset\)/);
  for (const preset of [
    'omarchy', 'islands', 'pills', 'material', 'outline',
    'rail', 'bracket', 'glow', 'powerline', 'mono', 'minimal'
  ]) {
    assert.match(panel, new RegExp(`value:\\s*['"]${preset}['"]`));
  }
});

test('panel and IPC use per-style profiles with a current-style defaults button', () => {
  const service = source('Service.qml');
  const panel = source('RicePanel.qml');
  assert.match(service, /RiceModel\.switchPreset\(pluginEntry,\s*value\)/);
  assert.match(panel, /RiceModel\.switchPreset\(settings,\s*value\)/);
  assert.match(panel, /RiceModel\.updateAppearance\(settings,\s*values\)/);
  assert.match(panel, /RiceModel\.resetPreset\(settings\)/);
  assert.match(panel, /Restore "\s*\+\s*root\.styleLabel\(root\.live\.preset\)\s*\+\s*" defaults/);
  assert.doesNotMatch(panel, /Restore default bar/);
});

test('style dropdown stays synchronized after external preset changes', () => {
  const panel = source('RicePanel.qml');
  assert.match(panel, /Dropdown\s*\{[\s\S]{0,80}id:\s*styleDropdown/);
  assert.match(panel, /Binding\s*\{[\s\S]{0,100}target:\s*styleDropdown[\s\S]{0,100}value:\s*root\.live\.preset/);
});

test('appearance controls are disabled only for the unmodified Default preset', () => {
  const panel = source('RicePanel.qml');
  assert.match(panel, /readonly property bool appearanceControlsEnabled:\s*live\.preset\s*!==\s*["']omarchy["']/);
  assert.equal((panel.match(/enabled:\s*root\.appearanceControlsEnabled/g) || []).length, 4);
});

test('chrome plans contrast against the actual stock widget foreground', () => {
  const chrome = source('RiceChrome.qml');
  assert.match(source('BarWidget.qml'), /foreground:\s*root\.bar \? root\.bar\.barForeground/);
  assert.match(chrome, /RiceModel\.contrastSurface\([\s\S]{0,100}Color\.bar\.background, foreground, Color\.accent, 4\.5\)/);
  assert.match(chrome, /RiceModel\.readableCompositePlan\([\s\S]{0,180}foreground, foreground, 4\.5, true\)/);
  for (const surface of ['materialSurface', 'adaptiveSurface', 'glowSurface', 'monoSurface'])
    assert.match(chrome, new RegExp(`return riceWindow\\.colorWithAlpha\\(riceWindow\\.${surface}, alpha\\)`));
});

test('all visual bar outlines follow the reactive Hyprland active-window border token', () => {
  const service = source('RiceChrome.qml');
  assert.match(service, /readonly property color themeBorderColor:\s*Color\.flatColor\([\s\S]{0,140}Color\.pick\(["']hyprland\.active-border["'],\s*Color\.accent\)/);
  assert.match(service, /id:\s*continuousRail[\s\S]{0,120}color:\s*riceWindow\.themeBorderColor/);
  assert.match(service, /readonly property color edgeRuleColor:\s*riceWindow\.themeBorderColor/);
  assert.match(service, /readonly property color outlineColor:[\s\S]{0,120}return riceWindow\.themeBorderColor/);
  assert.match(service, /strokeColor:\s*riceWindow\.themeBorderColor/);
  assert.match(service, /readonly property color bracketColor:\s*riceWindow\.themeBorderColor/);
  assert.doesNotMatch(service, /border\.color:\s*riceWindow\.adaptiveAccent/);
});

test('every style paint path honors exposed opacity radius and border controls', () => {
  const service = source('RiceChrome.qml');
  assert.match(service, /readonly property real opacityFactor:\s*riceWindow\.live\.opacity\s*\/\s*100/);
  assert.match(service, /readonly property int powerlineCut:[\s\S]{0,120}riceWindow\.live\.radius/);
  assert.match(service, /radius:\s*Math\.min\(riceWindow\.live\.radius,\s*rule\s*\/\s*2\)/);
  assert.match(service, /if\s*\(!riceWindow\.live\.border\)\s*return\s*["']transparent["']/);
  assert.match(service, /visible:\s*surface\.glow\s*&&\s*riceWindow\.live\.border/);
  assert.match(service, /bracketColor:\s*riceWindow\.themeBorderColor/);
  assert.match(service, /edgeRuleColor:\s*riceWindow\.themeBorderColor/);
  assert.doesNotMatch(service, /Math\.max\(0\.(?:68|82),\s*opacity/);
});

test('filled surfaces inset their background inside the visible border', () => {
  const service = source('RiceChrome.qml');
  assert.match(service, /id:\s*baseSurface[\s\S]{0,220}color:\s*["']transparent["']/);
  assert.match(service, /id:\s*innerFill[\s\S]{0,180}anchors\.margins:\s*baseSurface\.border\.width/);
  assert.match(service, /id:\s*innerFill[\s\S]{0,220}color:\s*surface\.fillColor/);
  assert.doesNotMatch(service, /id:\s*baseSurface[\s\S]{0,220}color:\s*surface\.fillColor/);
  assert.match(service, /ShapePath\s*\{[\s\S]{0,180}strokeWidth:\s*riceWindow\.live\.border\s*\?\s*1\s*:\s*0[\s\S]{0,180}fillColor:\s*surface\.fillColor/);
});

test('sparse readability backplates are instantiated only for sparse styles', () => {
  const service = source('RiceChrome.qml');
  assert.match(service, /id:\s*sparseBackplates[\s\S]{0,220}model:\s*riceWindow\.recipe\.decoration\s*===\s*["']rail["'][\s\S]{0,180}\?\s*riceWindow\.paintRects\s*:\s*\[\]/);
  assert.doesNotMatch(service, /id:\s*sparseBackplates\s*\n\s*model:\s*riceWindow\.paintRects/);
});

test('geometry polling preserves delegates when nothing moved', () => {
  assert.match(source('BarWidget.qml'), /JSON\.stringify\(next\) !== JSON\.stringify\(widgetGeometry\)/);
});

test('special styles are passive paint decorations over section geometry', () => {
  const service = source('RiceChrome.qml');
  assert.match(service, /RiceModel\.paintRecipe/);
  assert.match(service, /decoration\s*===\s*["']material["']/);
  assert.match(service, /decoration\s*===\s*["']outline["']/);
  assert.match(service, /decoration\s*===\s*["']rail["']/);
  assert.match(service, /decoration\s*===\s*["']bracket["']/);
  assert.match(service, /decoration\s*===\s*["']glow["']/);
  assert.match(service, /decoration\s*===\s*["']powerline["']/);
  assert.match(service, /decoration\s*===\s*["']mono["']/);
  assert.doesNotMatch(service, /WlrKeyboardFocus\.Exclusive|MouseArea|TapHandler/);
});

test('Glass is absent from every selectable and paint source', () => {
  for (const name of ['manifest.json', 'RicePanel.qml', 'RiceChrome.qml', 'README.md'])
    assert.doesNotMatch(source(name), /glass/i, name);
});
