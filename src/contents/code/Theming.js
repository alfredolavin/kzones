.pragma library
.import "ColorSpecCore.js" as Core

// Configurable colors of the overlay. `cfg.colorSpecs` maps an entity (selectorBackground, indicatorBorder …) to a
// color spec (see ColorSpecCore.js) whose source is "default" (the color the entity has without customization),
// "fixed", or "vivid" (an OKLCH color from the zone's index or its position on the screen, see cfg.vivid*).
// Entities without a spec keep their default exactly.

var SOURCES = ["default", "vivid"];

function toObj(c) {
    return { r: c.r, g: c.g, b: c.b, a: c.a === undefined ? 1 : c.a };
}

// ctx: { index, count, x, y } — the zone's index among `count`, and its center on the screen (0..1)
function vivid(cfg, ctx) {
    var by = cfg.colorizeBy || 0;
    var t = by === 1 ? ctx.x : by === 2 ? ctx.y : by === 3 ? (ctx.x + ctx.y) / 2 : (ctx.count > 0 ? ctx.index / ctx.count : 0);
    var hue = (cfg.vividHueStart !== undefined ? cfg.vividHueStart : 20) + (cfg.vividHueRange !== undefined ? cfg.vividHueRange : 360) * t;
    return Core.fromOklch((cfg.vividLightness !== undefined ? cfg.vividLightness : 72) / 100,
                          (cfg.vividChroma !== undefined ? cfg.vividChroma : 17) / 100, hue, 1);
}

// The color for `key`; `def` is its default color (a QML color)
function resolve(cfg, key, def, ctx) {
    var str = cfg && cfg.colorSpecs && cfg.colorSpecs[key];
    if (!str)
        return def;
    var spec = Core.parse(str, SOURCES.concat("fixed"));
    var base = spec.src === "fixed" ? spec.color : spec.src === "vivid" ? vivid(cfg, ctx || { index: 0, count: 1, x: 0.5, y: 0.5 }) : toObj(def);
    var c = Core.apply(spec, base);
    return Qt.rgba(c.r, c.g, c.b, c.a);
}

// Context of a layout zone {x, y, width, height} (percent) among `count`
function zoneCtx(zone, index, count) {
    return { index: index, count: count, x: (zone.x + zone.width / 2) / 100, y: (zone.y + zone.height / 2) / 100 };
}
