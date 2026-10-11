import QtQuick
import QtQuick.Shapes
import qs.Commons
import "RiceModel.js" as RiceModel

// Paint-only chrome. Hosted inside the stock bar window so Super+Shift+Space
// parks it with the widgets. It never accepts input or creates another window.
Item {
  id: riceWindow
  objectName: "rice-bar-chrome"

  property var live: RiceModel.snapshot({})
  readonly property string preset: live.preset
  property var widgetGeometry: []
  property string position: "top"
  property int barSize: 26
  property bool riceActive: true
  property color foreground: Color.bar.text

  readonly property var recipe: RiceModel.paintRecipe(preset)
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool edgeVertical: vertical
  readonly property int span: Math.max(0, barSize)
  readonly property var paintRects: rectsForPreset(preset, widgetGeometry)
  readonly property color adaptiveSurface: RiceModel.contrastSurface(
    Color.bar.background, foreground, Color.accent, 4.5)
  readonly property color adaptiveAccent: RiceModel.contrastColor(
    Color.accent, foreground, adaptiveSurface)
  readonly property color themeBorderColor: Color.flatColor(
    Color.pick("hyprland.active-border", Color.accent), Color.accent)
  readonly property color materialSurface: RiceModel.contrastSurface(
    blendColor(adaptiveSurface, adaptiveAccent, 0.15, 1), foreground, adaptiveAccent, 4.5)
  readonly property color glowSurface: RiceModel.contrastSurface(
    Qt.darker(adaptiveSurface, 1.28), foreground, adaptiveAccent, 4.5)
  readonly property color monoSurface: RiceModel.contrastSurface(
    Qt.darker(adaptiveSurface, 1.38), foreground, adaptiveAccent, 4.5)
  readonly property var contrastSurfaces: [recipe.decoration === "material" ? materialSurface
    : recipe.decoration === "glow" ? glowSurface
    : recipe.decoration === "mono" ? monoSurface : adaptiveSurface]
  readonly property real requestedSurfaceAlpha: RiceModel.visibleAlpha(live.opacity, 0.32)
  readonly property var contrastPlan: RiceModel.readableCompositePlan(
    contrastSurfaces, requestedSurfaceAlpha, foreground, foreground, 4.5, true)
  readonly property real surfaceAlpha: contrastPlan.alpha
  readonly property color surfaceColor: colorWithAlpha(adaptiveSurface, surfaceAlpha)

  function colorWithAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, Math.max(0, Math.min(1, alpha)))
  }

  function blendColor(first, second, weight, alpha) {
    var mix = Math.max(0, Math.min(1, Number(weight) || 0))
    return Qt.rgba(
      first.r * (1 - mix) + second.r * mix,
      first.g * (1 - mix) + second.g * mix,
      first.b * (1 - mix) + second.b * mix,
      Math.max(0, Math.min(1, alpha))
    )
  }

  function rectsForPreset(value, geometry) {
    var nextRecipe = RiceModel.paintRecipe(value)
    var axis = vertical ? "vertical" : "horizontal"
    var rects = []
    if (nextRecipe.geometry === "none") return rects
    if (nextRecipe.geometry === "widgets")
      rects = RiceModel.pillRects(geometry, Math.max(1, Math.floor(live.gap / 2)), null, axis)
    else
      rects = RiceModel.islandRects(geometry, live.gap)
    var separated = RiceModel.separateRects(rects, axis, 2)
    return nextRecipe.geometry === "widgets"
      ? RiceModel.balanceMenuPill(separated, axis)
      : separated
  }

  enabled: false
  clip: true
  visible: riceActive && span > 0 && paintRects.length > 0

  Rectangle {
    id: continuousRail
    visible: riceWindow.recipe.decoration === "rail"
    color: riceWindow.themeBorderColor
    radius: Math.min(riceWindow.live.radius, 1)
    x: riceWindow.edgeVertical
      ? (riceWindow.position === "left" ? riceWindow.span - 1 : 0) : 0
    y: riceWindow.edgeVertical
      ? 0 : (riceWindow.position === "top" ? riceWindow.span - 1 : 0)
    width: riceWindow.edgeVertical ? 1 : riceWindow.width
    height: riceWindow.edgeVertical ? riceWindow.height : 1
  }

  Repeater {
    id: sparseBackplates
    model: riceWindow.recipe.decoration === "rail"
      || riceWindow.recipe.decoration === "bracket"
      || riceWindow.recipe.decoration === "minimal"
      ? riceWindow.paintRects
      : []

    delegate: Rectangle {
      required property var modelData
      x: riceWindow.edgeVertical ? 1 : Math.max(0, modelData.x)
      y: riceWindow.edgeVertical ? Math.max(0, modelData.y) : 1
      width: riceWindow.edgeVertical
        ? Math.max(0, riceWindow.span - 2)
        : Math.max(0, Math.min(modelData.width, riceWindow.width - x))
      height: riceWindow.edgeVertical
        ? Math.max(0, Math.min(modelData.height, riceWindow.height - y))
        : Math.max(0, riceWindow.span - 2)
      radius: Math.min(riceWindow.live.radius, width / 2, height / 2)
      color: riceWindow.colorWithAlpha(riceWindow.adaptiveSurface, riceWindow.surfaceAlpha)
      antialiasing: true
    }
  }

  Repeater {
    model: riceWindow.paintRects

    delegate: Item {
      id: surface
      required property var modelData

      readonly property string decoration: String(riceWindow.recipe.decoration || "surface")
      readonly property bool minimal: decoration === "minimal"
      readonly property bool rail: decoration === "rail"
      readonly property bool material: decoration === "material"
      readonly property bool outline: decoration === "outline"
      readonly property bool bracket: decoration === "bracket"
      readonly property bool glow: decoration === "glow"
      readonly property bool powerline: decoration === "powerline"
      readonly property bool mono: decoration === "mono"
      readonly property bool edgeRule: minimal || rail
      readonly property int inset: edgeRule ? 0 : 2
      readonly property int rule: rail ? 3 : 2
      readonly property int desiredRadius: riceWindow.live.radius
      readonly property real opacityFactor: riceWindow.live.opacity / 100
      readonly property int powerlineCut: Math.max(2,
        Math.floor(Math.min(Math.min(width, height) / 3, 4 + riceWindow.live.radius / 3)))
      readonly property color edgeRuleColor: riceWindow.themeBorderColor
      readonly property color fillColor: {
        var alpha = riceWindow.surfaceAlpha
        if (material) return riceWindow.colorWithAlpha(riceWindow.materialSurface, alpha)
        if (outline) return riceWindow.colorWithAlpha(riceWindow.adaptiveSurface, alpha)
        if (glow) return riceWindow.colorWithAlpha(riceWindow.glowSurface, alpha)
        if (mono) return riceWindow.colorWithAlpha(riceWindow.monoSurface, alpha)
        return riceWindow.surfaceColor
      }
      readonly property color outlineColor: {
        if (!riceWindow.live.border) return "transparent"
        return riceWindow.themeBorderColor
      }

      x: {
        if (edgeRule && riceWindow.position === "left") return riceWindow.span - rule
        if (edgeRule && riceWindow.position === "right") return 0
        if (riceWindow.edgeVertical) return inset
        return Math.max(0, modelData.x)
      }
      y: {
        if (edgeRule && riceWindow.position === "top") return riceWindow.span - rule
        if (edgeRule && riceWindow.position === "bottom") return 0
        if (!riceWindow.edgeVertical) return inset
        return Math.max(0, modelData.y)
      }
      width: {
        if (edgeRule && riceWindow.edgeVertical) return rule
        if (riceWindow.edgeVertical) return Math.max(0, riceWindow.span - inset * 2)
        return Math.max(0, Math.min(modelData.width, riceWindow.width - x))
      }
      height: {
        if (edgeRule && !riceWindow.edgeVertical) return rule
        if (!riceWindow.edgeVertical) return Math.max(0, riceWindow.span - inset * 2)
        return Math.max(0, Math.min(modelData.height, riceWindow.height - y))
      }

      Rectangle {
        id: baseSurface
        anchors.fill: parent
        visible: !surface.edgeRule && !surface.bracket && !surface.powerline
        radius: Math.min(surface.desiredRadius, width / 2, height / 2)
        color: "transparent"
        clip: true
        border.width: {
          if (!riceWindow.live.border) return 0
          if (surface.outline) return 2
          return 1
        }
        border.color: surface.outlineColor
        antialiasing: true

        Rectangle {
          id: innerFill
          anchors.fill: parent
          anchors.margins: baseSurface.border.width
          color: surface.fillColor
          radius: Math.max(0, baseSurface.radius - baseSurface.border.width)
          antialiasing: true
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          visible: surface.glow && riceWindow.live.border
          color: "transparent"
          radius: Math.max(0, parent.radius - 2)
          border.width: 1
          border.color: riceWindow.colorWithAlpha(riceWindow.themeBorderColor, 0.34 * surface.opacityFactor)
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: 4
          visible: surface.glow && riceWindow.live.border
          color: "transparent"
          radius: Math.max(0, parent.radius - 4)
          border.width: 1
          border.color: riceWindow.colorWithAlpha(riceWindow.themeBorderColor, 0.14 * surface.opacityFactor)
        }
      }

      Shape {
        anchors.fill: parent
        visible: surface.powerline
        antialiasing: true
        ShapePath {
          strokeWidth: riceWindow.live.border ? 1 : 0
          strokeColor: riceWindow.themeBorderColor
          fillColor: surface.fillColor
          joinStyle: ShapePath.MiterJoin
          startX: riceWindow.edgeVertical ? 0 : surface.powerlineCut
          startY: riceWindow.edgeVertical ? surface.powerlineCut : 0
          PathLine {
            x: riceWindow.edgeVertical ? surface.width / 2 : surface.width - surface.powerlineCut
            y: riceWindow.edgeVertical ? 0 : 0
          }
          PathLine {
            x: riceWindow.edgeVertical ? surface.width : surface.width
            y: riceWindow.edgeVertical ? surface.powerlineCut : surface.height / 2
          }
          PathLine {
            x: surface.width
            y: riceWindow.edgeVertical ? surface.height - surface.powerlineCut : surface.height
          }
          PathLine {
            x: riceWindow.edgeVertical ? surface.width / 2 : surface.powerlineCut
            y: surface.height
          }
          PathLine {
            x: 0
            y: riceWindow.edgeVertical ? surface.height - surface.powerlineCut : surface.height / 2
          }
          PathLine {
            x: riceWindow.edgeVertical ? 0 : surface.powerlineCut
            y: riceWindow.edgeVertical ? surface.powerlineCut : 0
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: surface.edgeRule
        color: surface.edgeRuleColor
        radius: Math.min(riceWindow.live.radius, rule / 2)
      }

      Item {
        anchors.fill: parent
        visible: surface.bracket
        readonly property int length: Math.min(10, Math.max(5, Math.floor(Math.min(width, height) / 3)))
        readonly property int thickness: 2
        readonly property real cornerRadius: Math.min(riceWindow.live.radius, thickness / 2)
        readonly property color bracketColor: riceWindow.themeBorderColor

        Rectangle { x: 0; y: 0; width: parent.length; height: parent.thickness; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: 0; y: 0; width: parent.thickness; height: parent.length; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: parent.width - parent.length; y: 0; width: parent.length; height: parent.thickness; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: parent.width - parent.thickness; y: 0; width: parent.thickness; height: parent.length; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: 0; y: parent.height - parent.thickness; width: parent.length; height: parent.thickness; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: 0; y: parent.height - parent.length; width: parent.thickness; height: parent.length; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: parent.width - parent.length; y: parent.height - parent.thickness; width: parent.length; height: parent.thickness; radius: parent.cornerRadius; color: parent.bracketColor }
        Rectangle { x: parent.width - parent.thickness; y: parent.height - parent.length; width: parent.thickness; height: parent.length; radius: parent.cornerRadius; color: parent.bracketColor }
      }

      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
  }
}
