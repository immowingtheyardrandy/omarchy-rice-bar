import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "RiceModel.js" as RiceModel
import "GeometryProbe.js" as GeometryProbe

BarWidget {
  id: root
  moduleName: "io.github.jcarcinogen.rice-bar"

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  property var panelItem: null
  property var widgetGeometry: []
  readonly property var live: RiceModel.snapshot(settings)
  readonly property var hostWindow: root.QsWindow.window
  readonly property var chromeHost: hostWindow ? hostWindow.contentItem : null
  readonly property string position: bar && bar.position ? String(bar.position) : "top"

  function probeGeometry() {
    var next = GeometryProbe.geometryForHost(chromeHost, root.barSize, root.vertical, RiceModel.isSlotSized)
    // Keep the Repeater delegates and their animations when geometry is unchanged.
    if (JSON.stringify(next) !== JSON.stringify(widgetGeometry)) widgetGeometry = next
  }

  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() { if (panelItem) panelItem.toggle() }
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onChromeHostChanged: {
    widgetGeometry = []
    Qt.callLater(root.probeGeometry)
  }
  onPositionChanged: Qt.callLater(root.probeGeometry)
  onBarSizeChanged: Qt.callLater(root.probeGeometry)

  // Qt's Binding restores when deactivated; destruction alone does not restore
  // an active binding. Deactivate it while the host window is still alive.
  Component.onDestruction: windowTransparency.when = false

  Timer {
    interval: 250
    repeat: true
    running: root.live.preset !== "omarchy" && root.chromeHost !== null
    triggeredOnStart: true
    onTriggered: root.probeGeometry()
  }

  // Restore the stock color binding on Default, unload, and window changes.
  // No global bar state or shell.json transparency setting is changed.
  Binding {
    id: windowTransparency
    target: root.hostWindow
    property: "color"
    value: "transparent"
    when: chromeLoader.item !== null && chromeLoader.item.visible
    restoreMode: Binding.RestoreBindingOrValue
  }

  Loader {
    id: chromeLoader
    active: root.live.preset !== "omarchy" && root.chromeHost !== null
    sourceComponent: RiceChrome {
      parent: root.chromeHost
      anchors.fill: parent
      z: -1
      live: root.live
      widgetGeometry: root.widgetGeometry
      position: root.position
      barSize: root.barSize
      foreground: root.bar ? root.bar.barForeground : Color.bar.text
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("RicePanel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰟪"
    tooltipText: root.opened ? "Close Rice Bar styles" : "Rice Bar styles"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.togglePanel()
    }
  }
}
