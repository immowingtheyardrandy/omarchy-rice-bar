import QtQuick
import Quickshell
import qs.Ui
import "services" as HostServices
import "RiceBar" as RiceBar
import "RiceBar/RiceModel.js" as RiceModel

ShellRoot {
  id: testRoot
  property int step: 0
  property string failure: ""
  property color stockColor: "#123456"
  property var presets: RiceModel.PRESETS
  property var renderCases: {
    var result = []
    var positions = ["top", "bottom", "left", "right"]
    for (var p = 0; p < positions.length; p++)
      for (var s = 0; s < presets.length; s++) result.push({ preset: presets[s], position: positions[p] })
    return result
  }

  function chrome() {
    var children = host.contentItem.children
    for (var i = 0; i < children.length; i++)
      if (children[i].objectName === "rice-bar-chrome") return children[i]
    return null
  }

  function checkPreset(preset, position) {
    check(state.position === position, "stock position follows " + position)
    check(service.live.preset === preset, "service follows " + preset)
    var paint = chrome()
    if (preset === "omarchy") {
      check(!paint, "Default unloads the painter")
      check(peerHost.color.a === 0, "Default on one window leaves peer chrome intact")
      check(host.color === stockColor, "Default restores stock transparency")
    } else {
      check(!!paint && paint.visible, preset + " paints chrome")
      if (!paint) return
      check(paint.width === host.width && paint.height === host.height, "chrome covers its host window")
      check(paint.paintRects.length === 3, preset + " paints all occupied sections")
      check(!paint.enabled && paint.z < 0, "chrome is passive and behind the widgets")
      check(paint.contrastPlan.foreground === paint.foreground, "stock foreground is preserved")
      check(paint.contrastPlan.contrast >= 4.5, "paint retains readable text")
    }
  }

  function check(condition, message) {
    if (!condition) {
      failure = message
      console.error("RICE_RUNTIME_FAIL: " + message)
      Qt.quit()
    }
  }

  HostServices.PluginBarStateApi {
    id: state
    ownerPluginId: api.pluginId
    barSize: 26
  }

  PluginBarApi {
    id: api
    pluginId: "io.github.jcarcinogen.rice-bar"
    moduleName: pluginId
    shell: scopedShell
    barSize: 26
    fontFamily: "monospace"
    foreground: "#ffffff"
    barForeground: "#ffffff"
    position: state.position
    vertical: position === "left" || position === "right"
  }

  HostServices.PluginShellApi {
    id: scopedShell
    pluginId: api.pluginId
    bar: state
    barConfig: ({ transparent: false, layout: { right: [{ id: api.pluginId, preset: "islands" }] } })
    property string lastAction: ""
    property bool rejectUpdates: false
    _updateSettings: function(id, next) {
      if (rejectUpdates || id !== api.pluginId) return false
      barConfig = { transparent: false, layout: { right: [Object.assign({ id: id }, next)] } }
      if (widgetLoader.item) widgetLoader.item.settings = next
      return true
    }
    _summon: function(id, payload) { lastAction = "summon:" + id; return true }
    _hide: function(id) { lastAction = "hide:" + id; return true }
    _toggle: function(id, payload) { lastAction = "toggle:" + id; return true }
  }

  RiceBar.Service {
    id: service
    shell: scopedShell
  }

  FloatingWindow {
    id: host
    visible: true
    implicitWidth: api.vertical ? 26 : 800
    implicitHeight: api.vertical ? 800 : 26
    color: testRoot.stockColor

    Item {
      x: api.vertical ? 0 : 10
      y: api.vertical ? 10 : 0
      width: api.vertical ? 26 : 28
      height: api.vertical ? 28 : 26
      property string moduleName: "omarchy.menu"
      property string region: "left"
      property var activeItem: content
      Item { id: content; anchors.fill: parent }
    }

    Item {
      x: api.vertical ? 0 : 350
      y: api.vertical ? 350 : 0
      width: api.vertical ? 26 : 70
      height: api.vertical ? 70 : 26
      property string moduleName: "omarchy.clock"
      property string region: "center"
      property var activeItem: clock
      Item { id: clock; anchors.fill: parent }
    }

    Item {
      x: api.vertical ? 0 : 750
      y: api.vertical ? 750 : 0
      width: api.vertical ? 26 : 28
      height: api.vertical ? 28 : 26
      property string moduleName: api.pluginId
      property string region: "right"
      property var activeItem: widgetLoader.item
      Loader {
        id: widgetLoader
        anchors.fill: parent
        sourceComponent: RiceBar.BarWidget { bar: api; settings: ({ preset: "islands" }) }
      }
    }
  }

  FloatingWindow {
    id: peerHost
    visible: true
    implicitWidth: 120
    implicitHeight: 26
    color: testRoot.stockColor
    Item {
      width: 28
      height: 26
      property string moduleName: api.pluginId
      property string region: "right"
      property var activeItem: peerLoader.item
      Loader {
        id: peerLoader
        anchors.fill: parent
        sourceComponent: RiceBar.BarWidget { bar: api; settings: ({ preset: "islands" }) }
      }
    }
  }

  Timer {
    interval: 80
    repeat: true
    running: true
    onTriggered: {
      if (testRoot.failure) return
      var widget = widgetLoader.item
      if (testRoot.step === 8 + testRoot.renderCases.length) {
        testRoot.check(host.color === testRoot.stockColor, "unloading restores the stock binding")
        if (!testRoot.failure) console.log("RICE_RUNTIME_PASS")
        Qt.quit()
        return
      }
      testRoot.check(!!widget, "widget loads with the 4.0.4 scoped API")
      if (!widget) return
      if (testRoot.step === 0) {
        testRoot.check(!!widget.panelItem, "settings panel loads")
        widget.probeGeometry()
        testRoot.check(widget.widgetGeometry.length === 3, "geometry includes only its own three sections")
        peerLoader.item.probeGeometry()
        testRoot.check(peerLoader.item.widgetGeometry.length === 1, "peer geometry belongs to its own window")
        testRoot.check(widget.chromeHost === host.contentItem, "chrome uses the widget's own window")
      } else if (testRoot.step === 1) {
        testRoot.check(host.color.a === 0, "Rice Bar makes only its window transparent")
        testRoot.check(scopedShell.barConfig.transparent === false, "global transparency stays unchanged")
        testRoot.check(service.panelAction("summon"), "service summons its scoped panel")
        testRoot.check(scopedShell.lastAction === "summon:" + api.pluginId, "panel route uses the plugin id")
        widget.panelItem.persistAppearance({ radius: 9 })
        testRoot.check(service.live.radius === 9, "panel settings reach the service snapshot")
        testRoot.check(service.persistPreset("islands"), "repeating the active style succeeds")
        scopedShell.rejectUpdates = true
        var next = RiceModel.updateAppearance(widget.settings, { radius: 17 })
        testRoot.check(!widget.panelItem.persistSettings(next), "panel reports rejected saves")
        testRoot.check(widget.live.radius === 9, "rejected panel saves retain actual settings")
        testRoot.check(!service.persistPreset("glow"), "service reports rejected saves")
        testRoot.check(service.live.preset === "islands", "rejected IPC saves retain the style")
        scopedShell.rejectUpdates = false
      } else if (testRoot.step >= 2 && testRoot.step < 2 + testRoot.renderCases.length) {
        if (testRoot.step > 2) {
          var previous = testRoot.renderCases[testRoot.step - 3]
          testRoot.checkPreset(previous.preset, previous.position)
        }
        var current = testRoot.renderCases[testRoot.step - 2]
        state.position = current.position
        api.barForeground = api.vertical ? "#777777" : "#ffffff"
        widget.probeGeometry()
        testRoot.check(service.persistPreset(current.preset), "IPC saves " + current.preset)
      } else if (testRoot.step === 2 + testRoot.renderCases.length) {
        testRoot.checkPreset("minimal", "right")
        state.position = "left"
        api.barForeground = "#777777"
        widget.probeGeometry()
      } else if (testRoot.step === 3 + testRoot.renderCases.length) {
        state.barHidden = true
        testRoot.check(service.barHidden, "service reads scalar visibility")
        host.visible = false
        testRoot.check(!host.visible, "chrome shares the hidden stock window")
        testRoot.stockColor = "#abcdef"
        service.persistPreset("omarchy")
      } else if (testRoot.step === 4 + testRoot.renderCases.length) {
        testRoot.check(host.color === testRoot.stockColor, "Default restores the stock color binding")
        testRoot.stockColor = "#654321"
      } else if (testRoot.step === 5 + testRoot.renderCases.length) {
        testRoot.check(host.color === testRoot.stockColor, "restored binding tracks new stock colors")
        host.visible = true
        service.persistPreset("islands")
      } else if (testRoot.step === 6 + testRoot.renderCases.length) {
        widget.probeGeometry()
      } else if (testRoot.step === 7 + testRoot.renderCases.length) {
        testRoot.check(host.color.a === 0, "chrome can be enabled again")
        widgetLoader.active = false
      }
      testRoot.step++
    }
  }

  Timer {
    interval: 8000
    running: true
    onTriggered: { console.error("RICE_RUNTIME_FAIL: timeout"); Qt.quit() }
  }
}
