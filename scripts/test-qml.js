const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

// Use installed Omarchy components and a separate test window; never install
// the plugin or touch the user's shell.json or live shell instance.
const shellPath = path.join(process.env.OMARCHY_PATH || '/usr/share/omarchy', 'shell');
if (!process.env.WAYLAND_DISPLAY || !fs.existsSync(path.join(shellPath, 'Ui', 'PluginBarApi.qml'))) {
  console.error('QML runtime tests require a Wayland session and Omarchy 4.0.4 components.');
  process.exit(1);
}
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'rice-bar-qml-'));
try {
  const root = path.resolve(__dirname, '..');
  fs.copyFileSync(path.join(root, 'tests', 'qml', 'shell.qml'), path.join(temp, 'shell.qml'));
  fs.symlinkSync(root, path.join(temp, 'RiceBar'), 'dir');
  for (const dir of ['Commons', 'Ui', 'services']) fs.symlinkSync(path.join(shellPath, dir), path.join(temp, dir), 'dir');
  fs.mkdirSync(path.join(temp, 'runtime'), { mode: 0o700 });
  const display = path.isAbsolute(process.env.WAYLAND_DISPLAY) ? process.env.WAYLAND_DISPLAY
    : path.join(process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`, process.env.WAYLAND_DISPLAY);
  const result = spawnSync('qs', ['-p', temp, '--no-color'], {
    env: { ...process.env, WAYLAND_DISPLAY: display, XDG_RUNTIME_DIR: path.join(temp, 'runtime'),
      XDG_CACHE_HOME: path.join(temp, 'cache'), QT_QPA_PLATFORM: 'wayland', QT_QPA_PLATFORMTHEME: '', QT_STYLE_OVERRIDE: 'Fusion' },
    encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024
  });
  const output = (result.stdout || '') + (result.stderr || '');
  process.stdout.write(output);
  if (result.error || result.status !== 0 || !output.includes('RICE_RUNTIME_PASS')
      || /RICE_RUNTIME_FAIL|ERROR|WARN.*(?:scene|qml)/.test(output)) {
    if (result.error) console.error(result.error.message);
    process.exitCode = 1;
  }
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
