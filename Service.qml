import QtQuick
import Quickshell.Io
import "RiceModel.js" as RiceModel

// Headless IPC service. Only the scoped shell API is used here; painting and
// temporary window transparency belong to each stock-bar widget instance.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.jcarcinogen.rice-bar"
  readonly property var bar: shell && shell.bar ? shell.bar : null
  readonly property var pluginConfig: RiceModel.configFromShell(shell)
  readonly property var pluginEntry: RiceModel.findEntry(pluginConfig, pluginId)
  readonly property var live: RiceModel.snapshot(pluginEntry)
  readonly property bool barHidden: bar ? bar.barHidden === true : false
  readonly property string position: bar && bar.position ? String(bar.position) : "top"

  function persistPreset(value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    // The host returns false for an unchanged entry. Repeating a style command
    // should still succeed without rewriting its profile.
    if (pluginEntry.id === pluginId && live.preset === RiceModel.normalizePreset(value)) return true
    return shell.updateEntryInline(pluginId, RiceModel.switchPreset(pluginEntry, value)) === true
  }

  function panelAction(action) {
    if (["summon", "hide", "toggle"].indexOf(action) === -1) return false
    if (!shell || typeof shell[action] !== "function") return false
    return shell[action](pluginId) === true
  }

  IpcHandler {
    target: "rice-bar"

    function status(): string {
      return JSON.stringify({
        id: root.pluginId,
        architecture: "stock-overlay",
        preset: root.live.preset,
        shown: root.live.preset !== "omarchy" && !root.barHidden && !!root.bar,
        position: root.position,
        stockBar: !!root.bar,
        stockRequestedTransparent: !!(root.pluginConfig && root.pluginConfig.bar
          && root.pluginConfig.bar.transparent === true),
        geometrySource: "host-window"
      })
    }

    function style(value: string): string {
      var preset = RiceModel.normalizePreset(value)
      return root.persistPreset(preset) ? preset : "error: could not save Rice Bar settings"
    }

    function open(): void { root.panelAction("summon") }
    function close(): void { root.panelAction("hide") }
    function toggle(): void { root.panelAction("toggle") }
  }
}
