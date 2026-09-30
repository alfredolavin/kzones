import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "colorspec" as CS
import "colorspec/ColorSpecCore.js" as Core

// Colors of everything the overlay draws, each a configurable color (colorspec/): the default look, a fixed color,
// or a vivid OKLCH color computed from the zone's index or its place on the screen, then adjusted in
// luminosity, chroma, hue and opacity.
QQC2.ScrollView {
    id: page
    contentWidth: availableWidth

    readonly property var specs: { try { return JSON.parse(app.v.colorSpecs || "{}") || {}; } catch (e) { return {}; } }
    readonly property string plain: '{"src":"default","color":"#ffffffff","l":0,"c":0,"a":100}'

    // what "vivid" gives for a zone at t (0..1 along the chosen order)
    function vividAt(t) {
        return Core.fromOklch(app.v.vividLightness / 100, app.v.vividChroma / 100, app.v.vividHueStart + app.v.vividHueRange * t, 1);
    }
    function setSpec(key, str) {
        const m = Object.assign({}, specs);
        const s = Core.parse(str, ["fixed", "default", "vivid"]);
        if (s.src === "default" && !s.l && !s.c && !s.h && s.a >= 100)
            delete m[key];
        else
            m[key] = str;
        app.set("colorSpecs", JSON.stringify(m));
    }

    // one color setting
    component Entity: CS.ColorSpecButton {
        required property string key
        property color fallback: Kirigami.Theme.backgroundColor
        value: page.specs[key] || page.plain
        dialogTitle: Kirigami.FormData.label.replace(/:$/, "")
        sources: [{ id: "default", name: "Default" }, { id: "vivid", name: "Vivid (by zone)" }]
        baseColor: (src, fixedColor, ctx) => src === "vivid" ? page.vividAt(0.3) : src === "default" ? fallback : fixedColor
        onEdited: v => page.setSpec(key, v)
    }
    function themed(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha); }

    Kirigami.FormLayout {
        width: page.availableWidth

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Vivid colors" }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Colorize by:"
            model: ["Zone index", "Horizontal position", "Vertical position", "Diagonal position"]
            currentIndex: app.v.colorizeBy
            onActivated: index => app.set("colorizeBy", index)
            QQC2.ToolTip.text: "Vivid colors take their hue from the zone's index in its layout, or from where the zone sits on the screen"
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
        CS.ColorStripSlider {
            Kirigami.FormData.label: "Lightness:"
            from: 30; to: 95; stepSize: 1; suffix: " %"
            value: app.v.vividLightness
            colorAt: v => Core.fromOklch(v / 100, app.v.vividChroma / 100, app.v.vividHueStart, 1)
            repaintKey: [app.v.vividChroma, app.v.vividHueStart]
            onMoved: app.set("vividLightness", Math.round(value))
        }
        CS.ColorStripSlider {
            Kirigami.FormData.label: "Chroma:"
            from: 0; to: 35; stepSize: 1
            value: app.v.vividChroma
            colorAt: v => Core.fromOklch(app.v.vividLightness / 100, v / 100, app.v.vividHueStart, 1)
            repaintKey: [app.v.vividLightness, app.v.vividHueStart]
            onMoved: app.set("vividChroma", Math.round(value))
        }
        CS.ColorStripSlider {
            Kirigami.FormData.label: "First hue:"
            from: 0; to: 360; stepSize: 5; suffix: "°"
            value: app.v.vividHueStart
            colorAt: v => Core.fromOklch(app.v.vividLightness / 100, app.v.vividChroma / 100, v, 1)
            repaintKey: [app.v.vividLightness, app.v.vividChroma]
            onMoved: app.set("vividHueStart", Math.round(value))
        }
        CS.ColorStripSlider {
            Kirigami.FormData.label: "Hue span:"
            from: -360; to: 360; stepSize: 10; suffix: "°"
            value: app.v.vividHueRange
            colorAt: v => Core.fromOklch(app.v.vividLightness / 100, app.v.vividChroma / 100, app.v.vividHueStart + v * 0.5, 1)
            repaintKey: [app.v.vividLightness, app.v.vividChroma, app.v.vividHueStart]
            onMoved: app.set("vividHueRange", Math.round(value))
        }
        RowLayout {
            Kirigami.FormData.label: "Preview:"
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: 8
                CS.Swatch {
                    required property int index
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                    color: { const c = page.vividAt(index / 8); return Qt.rgba(c.r, c.g, c.b, 1); }
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Zone selector (top of the screen)" }
        Entity { key: "selectorBackground"; Kirigami.FormData.label: "Background:"; fallback: Kirigami.Theme.backgroundColor }
        Entity { key: "selectorBorder"; Kirigami.FormData.label: "Border:"; fallback: page.themed(Kirigami.Theme.textColor, 0.2) }
        Entity { key: "shadow"; Kirigami.FormData.label: "Shadow:"; fallback: Qt.rgba(0, 0, 0, 0.4) }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Zone indicator (box shown in each zone)" }
        Entity { key: "indicatorBackground"; Kirigami.FormData.label: "Background:"; fallback: Kirigami.Theme.backgroundColor }
        Entity { key: "indicatorBorder"; Kirigami.FormData.label: "Border:"; fallback: page.themed(Kirigami.Theme.textColor, 0.2) }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Layout preview (zones drawn inside the boxes)" }
        Entity { key: "miniZone"; Kirigami.FormData.label: "Zone:"; fallback: Kirigami.Theme.alternateBackgroundColor }
        Entity { key: "miniZoneActive"; Kirigami.FormData.label: "Highlighted zone:"; fallback: Kirigami.Theme.hoverColor }
        Entity { key: "miniZoneBorder"; Kirigami.FormData.label: "Border:"; fallback: page.themed(Kirigami.Theme.textColor, 0.2) }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Zone highlight (over the screen)" }
        Entity { key: "highlightBorder"; Kirigami.FormData.label: "Border:"; fallback: Kirigami.Theme.hoverColor }
        Entity { key: "highlightFill"; Kirigami.FormData.label: "Fill:"; fallback: Kirigami.Theme.hoverColor }

        QQC2.Label {
            Kirigami.FormData.label: ""
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Zones with their own \"color\" in the layouts keep it as the Default. The highlight fill is drawn at 10 % strength, so a fixed color's opacity multiplies with that."
        }
    }
}
