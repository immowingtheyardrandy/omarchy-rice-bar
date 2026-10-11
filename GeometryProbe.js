// Read only the visual children of the widget's own window. Never search the
// shell/service object graph or infer visibility from global screen coordinates.
function walk(item, visit) {
  var stack = [{ item: item, depth: 0 }]
  var seen = []
  while (stack.length && seen.length < 512) {
    var next = stack.pop()
    var current = next.item
    if (!current || next.depth > 16 || seen.indexOf(current) !== -1) continue
    seen.push(current)
    if (current.visible === false || visit(current) === false) continue
    var children = current.children || []
    for (var i = Math.min(children.length, 512) - 1; i >= 0; i--)
      stack.push({ item: children[i], depth: next.depth + 1 })
  }
}

function record(item, host, id, section) {
  if (!item || item.visible === false || typeof item.mapToItem !== "function") return null
  var width = Number(item.width), height = Number(item.height)
  if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) return null
  var point
  try { point = item.mapToItem(host, 0, 0) } catch (error) { return null }
  if (!point || !isFinite(Number(point.x)) || !isFinite(Number(point.y))) return null
  return {
    id: String(id), section: String(section),
    x: Math.round(point.x), y: Math.round(point.y),
    width: Math.round(width), height: Math.round(height),
    visible: true, itemVisible: true
  }
}

function trayLeaves(slot, host, parent, barSize, vertical, isSlotSized) {
  var leaves = []
  walk(slot.activeItem, function(item) {
    if (!isSlotSized(item.width, item.height, barSize)) return
    var leaf = record(item, host, "omarchy.tray." + leaves.length, slot.region)
    if (!leaf) return
    var pos = vertical ? "x" : "y"
    var size = vertical ? "width" : "height"
    var overlap = Math.min(leaf[pos] + leaf[size], parent[pos] + parent[size])
      - Math.max(leaf[pos], parent[pos])
    if (overlap > leaf[size] * 0.4) leaves.push(leaf)
  })
  return leaves
}

function geometryForHost(host, barSize, vertical, isSlotSized) {
  var result = []
  if (!host || typeof isSlotSized !== "function") return result
  walk(host, function(item) {
    if (item.objectName === "rice-bar-chrome") return false
    if (item.moduleName === undefined || item.region === undefined
        || item.activeItem === undefined) return
    if (!item.activeItem || item.activeItem.visible === false) return false
    var slot = record(item, host, item.moduleName, item.region)
    if (slot) {
      slot.leaves = slot.id === "omarchy.tray"
        ? trayLeaves(item, host, slot, barSize, vertical, isSlotSized) : []
      result.push(slot)
    }
    return false
  })
  return result
}

if (typeof module !== "undefined" && module.exports)
  module.exports = { geometryForHost: geometryForHost }
